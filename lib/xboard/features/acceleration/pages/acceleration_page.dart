import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import '../coordinator.dart';
import '../entrance_probe.dart';

class AccelerationPage extends StatefulWidget {
  final AccelerationCoordinator coordinator;
  final EntranceProbe? probe;
  const AccelerationPage({super.key, required this.coordinator, this.probe});
  @override
  State<AccelerationPage> createState() => _AccelerationPageState();
}

class _AccelerationPageState extends State<AccelerationPage> {
  AccelerationCatalog? _catalog;
  Set<String> _selected = {};
  Duration? _latency;
  bool _loading = true;
  String? _loadError;
  Timer? _probeTimer;
  bool _probing = false;
  int _probeEpoch = 0;
  AccelerationCoordinator get coordinator => widget.coordinator;

  @override
  void initState() {
    super.initState();
    coordinator.addListener(_changed);
    unawaited(_load());
    _probeTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => unawaited(_probe()));
  }

  Future<void> _load() async {
    try {
      final catalog = await coordinator.api.catalog();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _selected = Set.of(coordinator.selectedApplications);
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = '暂时无法加载应用，请稍后重试';
        });
      }
    }
  }

  void _changed() {
    if (!mounted) return;
    if (coordinator.phase != 'connected') {
      _latency = null;
      _probeEpoch++;
    }
    setState(() {});
    if (coordinator.phase == 'connected') unawaited(_probe());
  }

  Future<void> _probe() async {
    if (_probing ||
        coordinator.phase != 'connected' ||
        coordinator.entrances.isEmpty) {
      return;
    }
    final entrance = coordinator.entrances.first;
    if (entrance['probe'] != 'tcp') return;
    final epoch = _probeEpoch;
    _probing = true;
    final result = await (widget.probe ?? EntranceProbe())
        .measure(entrance['host'] as String, entrance['port'] as int);
    _probing = false;
    if (mounted && epoch == _probeEpoch && coordinator.phase == 'connected') {
      setState(() => _latency = result);
    }
  }

  String get _status {
    if (coordinator.phase == 'connected') return '已连接';
    if (coordinator.phase == 'idle') return '选择应用后开启加速';
    if (coordinator.phase == 'preparing') return '正在准备，保护尚未建立';
    if (coordinator.phase == 'protected') return '已建立保护，正在准备加速资源';
    if (!coordinator.protectionActive) return '加速未启动或保护已中断，当前使用系统网络';
    return switch (coordinator.errorCode) {
      'REALNAME_REQUIRED' => '请先到个人中心完成实名认证；所选应用已暂停联网',
      'PREPARATION_PENDING' => '资源仍在准备中，所选应用已暂停联网，请稍后重试',
      'CONFIG_EXPIRED' => '连接配置已过期，所选应用已暂停联网',
      'ACCELERATION_DISABLED' => '当前账户尚未开通应用加速，所选应用已暂停联网',
      _ => '加速暂不可用，所选应用已暂停联网',
    };
  }

  @override
  Widget build(BuildContext context) {
    final busy = {'preparing', 'protected'}.contains(coordinator.phase);
    return Scaffold(
        appBar: AppBar(title: const Text('应用加速')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(padding: const EdgeInsets.all(24), children: [
                  Text(_status, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text(
                      '入口连接延迟：${_latency == null ? '暂无数据' : '${_latency!.inMilliseconds} ms'}'),
                  const SizedBox(height: 16),
                  if (_loading) const LinearProgressIndicator(),
                  if (_loadError != null) Text(_loadError!),
                  for (final app
                      in _catalog?.applications ?? <AccelerationApplication>[])
                    CheckboxListTile(
                        title: Text(app.name),
                        value: _selected.contains(app.id),
                        onChanged: busy || coordinator.phase == 'connected'
                            ? null
                            : (checked) => setState(() => checked == true
                                ? _selected.add(app.id)
                                : _selected.remove(app.id))),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: _selected.isEmpty ||
                              busy ||
                              coordinator.phase == 'connected'
                          ? null
                          : () => coordinator.start(_selected),
                      child: const Text('开启加速')),
                  if (coordinator.phase != 'idle')
                    OutlinedButton(
                        onPressed: () => coordinator.stop(),
                        child: const Text('停止加速')),
                  const SizedBox(height: 12),
                  const Text('仅加速所选应用，其余流量使用普通网络。入口连接延迟不代表应用全链路延迟。'),
                ]))));
  }

  @override
  void dispose() {
    _probeEpoch++;
    _probeTimer?.cancel();
    coordinator.removeListener(_changed);
    super.dispose();
  }
}
