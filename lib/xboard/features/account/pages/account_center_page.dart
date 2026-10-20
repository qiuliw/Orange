import 'dart:io';

import 'package:fl_clash/xboard/features/account/providers/real_name_provider.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/invite/widgets/user_menu_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 个人中心：展示账号信息与实名状态
class AccountCenterPage extends ConsumerStatefulWidget {
  const AccountCenterPage({super.key});

  @override
  ConsumerState<AccountCenterPage> createState() => _AccountCenterPageState();
}

class _AccountCenterPageState extends ConsumerState<AccountCenterPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(realNameProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    final userInfo = ref.watch(userInfoProvider);
    final realName = ref.watch(realNameProvider);
    final email = ref.watch(xboardUserProvider).email ?? userInfo?.email ?? '-';
    final verified = realName.verified;
    final required = realName.required;

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
        actions: isDesktop ? null : const [UserMenuWidget()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(xboardUserProvider.notifier).refreshUserInfo(),
            ref.read(realNameProvider.notifier).refresh(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: (userInfo?.avatarUrl.isNotEmpty ?? false)
                      ? NetworkImage(userInfo!.avatarUrl)
                      : null,
                  child: (userInfo?.avatarUrl.isEmpty ?? true)
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(email),
                subtitle: Text(
                  verified
                      ? '已实名'
                      : (required ? '未实名（购买/订阅前需完成）' : '未实名'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(
                  verified ? Icons.verified_user : Icons.gpp_maybe_outlined,
                  color: verified ? Colors.green : Colors.orange,
                ),
                title: const Text('实名认证'),
                subtitle: Text(
                  verified
                      ? '${realName.realName ?? ''}  ${realName.idNumberMask ?? ''}'.trim()
                      : '完成支付宝实名后可购买套餐与获取订阅',
                ),
                trailing: realName.loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : verified
                        ? const Chip(
                            label: Text('已认证'),
                            backgroundColor: Color(0xFFE8F5E9),
                          )
                        : FilledButton(
                            onPressed: () async {
                              await context.push('/account/real-name');
                              if (mounted) {
                                ref.read(realNameProvider.notifier).refresh();
                              }
                            },
                            child: const Text('去实名'),
                          ),
              ),
            ),
            if (realName.error != null) ...[
              const SizedBox(height: 12),
              Text(
                realName.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
