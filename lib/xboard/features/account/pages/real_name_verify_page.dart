import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/account/providers/real_name_provider.dart';
import 'package:fl_clash/xboard/features/invite/widgets/qr_code_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:url_launcher/url_launcher.dart';

/// 支付宝身份验证（FACE）：桌面扫码 / 移动端唤起。
class RealNameVerifyPage extends ConsumerStatefulWidget {
  const RealNameVerifyPage({super.key});

  @override
  ConsumerState<RealNameVerifyPage> createState() => _RealNameVerifyPageState();
}

class _RealNameVerifyPageState extends ConsumerState<RealNameVerifyPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _certController = TextEditingController();
  bool _submitting = false;
  bool _waitingAuth = false;
  String? _authUrl;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(realNameProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _nameController.dispose();
    _certController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
      _authUrl = null;
    });

    try {
      final result = await XBoardSDK.instance.user.startRealNameVerify(
        realName: _nameController.text.trim(),
        certNo: _certController.text.trim(),
      );
      await ref.read(realNameProvider.notifier).refresh();

      if (result.verified) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已完成实名认证')),
          );
          Navigator.of(context).pop(true);
        }
        return;
      }

      final authUrl = result.authUrl;
      if (authUrl == null || authUrl.isEmpty) {
        throw Exception('未获取到支付宝认证链接');
      }

      if (system.isDesktop) {
        setState(() {
          _authUrl = authUrl;
          _waitingAuth = true;
        });
        _startPolling();
        return;
      }

      final launched = await launchUrl(
        Uri.parse(authUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('无法打开支付宝认证页面');
      }

      setState(() {
        _authUrl = authUrl;
        _waitingAuth = true;
      });
      _startPolling();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^(Exception|ApiException):\s*'), '');
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        await ref.read(realNameProvider.notifier).refresh();
        if (ref.read(realNameProvider).verified) {
          _pollTimer?.cancel();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('实名认证成功')),
          );
          Navigator.of(context).pop(true);
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final realName = ref.watch(realNameProvider);
    if (realName.verified) {
      return Scaffold(
        appBar: AppBar(title: const Text('实名认证')),
        body: const Center(child: Text('您已完成实名认证')),
      );
    }

    final isDesktop = system.isDesktop;

    return Scaffold(
      appBar: AppBar(title: const Text('实名认证')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            isDesktop
                ? '请填写与支付宝实名一致的姓名和身份证号，提交后用手机支付宝扫描二维码完成人脸核验。'
                : '请填写与支付宝实名一致的姓名和身份证号，提交后将打开支付宝完成人脸核验。',
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '真实姓名',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !_waitingAuth,
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return '请输入真实姓名';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _certController,
                  decoration: const InputDecoration(
                    labelText: '身份证号',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !_waitingAuth,
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (!RegExp(r'^\d{17}[\dXx]$').hasMatch(v)) {
                      return '请输入正确的身份证号';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_waitingAuth && isDesktop && _authUrl != null) ...[
            const SizedBox(height: 24),
            const Text(
              '请使用手机支付宝扫描下方二维码完成人脸认证',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Center(child: QrCodeWidget(data: _authUrl!, size: 220)),
          ],
          if (_waitingAuth) ...[
            const SizedBox(height: 16),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircularProgressIndicator(),
              title: Text('等待支付宝人脸认证结果…'),
              subtitle: Text('完成后将自动返回，也可手动刷新状态'),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting || _waitingAuth ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _waitingAuth
                        ? '等待认证中'
                        : (isDesktop ? '提交并显示二维码' : '提交并打开支付宝'),
                  ),
          ),
          if (_waitingAuth) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                await ref.read(realNameProvider.notifier).refresh();
                if (ref.read(realNameProvider).verified && mounted) {
                  Navigator.of(context).pop(true);
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isDesktop
                            ? '尚未完成实名，请先用手机支付宝扫码完成人脸认证'
                            : '尚未完成实名，请先在支付宝完成人脸认证',
                      ),
                    ),
                  );
                }
              },
              child: const Text('我已完成认证，刷新状态'),
            ),
            if (!isDesktop && _authUrl != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(_authUrl!),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('重新打开支付宝'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
