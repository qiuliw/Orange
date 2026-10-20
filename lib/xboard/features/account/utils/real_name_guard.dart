import 'package:fl_clash/xboard/features/account/providers/real_name_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 实名拦截：与后端 status.required / assertVerified 对齐。
class RealNameGuard {
  static Future<bool> ensureVerified(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final notifier = ref.read(realNameProvider.notifier);
    await notifier.refresh();
    final status = ref.read(realNameProvider);

    if (status.verified || !status.required) {
      return true;
    }
    if (!context.mounted) return false;
    return _promptAndNavigate(context, ref);
  }

  static Future<void> handleBackendDenied(
    BuildContext context,
    WidgetRef ref,
    Object error,
  ) async {
    final msg = error.toString();
    final denied = msg.contains('实名') ||
        msg.contains('40301') ||
        msg.contains('real_name') ||
        msg.contains('real name verification required');
    if (!denied || !context.mounted) return;
    await _promptAndNavigate(context, ref);
  }

  static Future<bool> _promptAndNavigate(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final goVerify = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('需要实名认证'),
          content: const Text('购买套餐或获取订阅前，请先完成实名认证。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('稍后'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('去实名'),
            ),
          ],
        );
      },
    );

    if (goVerify == true && context.mounted) {
      final result = await context.push<bool>('/account/real-name');
      if (result == true) return true;
      await ref.read(realNameProvider.notifier).refresh();
      return ref.read(realNameProvider).verified;
    }
    return false;
  }
}
