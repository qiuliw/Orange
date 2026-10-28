import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'core_config_port.dart';
import 'rule_builder.dart';

class AccelerationCoordinator extends ChangeNotifier {
  final AccelerationApi api;
  final CoreConfigPort core;
  final DateTime Function() now;
  final Future<void> Function(Duration) delay;
  AccelerationCoordinator(
      {required this.api,
      required this.core,
      DateTime Function()? now,
      Future<void> Function(Duration)? delay})
      : now = now ?? DateTime.now,
        delay = delay ?? Future<void>.delayed;

  String phase = 'idle';
  String? errorCode;
  bool protectionActive = false;
  AccelerationCatalog? catalog;
  AccelerationConfig? _config;
  Set<String> _selected = {};
  int _epoch = 0;
  bool _disposed = false;
  Timer? _expiry, _refreshTimer;
  bool _refreshing = false;
  final _builder = AccelerationRuleBuilder();
  Set<String> get selectedApplications => Set.unmodifiable(_selected);
  List<Map<String, dynamic>> get entrances => _config?.entrances ?? const [];

  bool _current(int epoch) => !_disposed && epoch == _epoch;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start(Set<String> applicationIds) async {
    core.invalidatePendingOperations();
    final epoch = ++_epoch;
    _expiry?.cancel();
    _refreshTimer?.cancel();
    phase = 'preparing';
    errorCode = null;
    final selected = Set<String>.unmodifiable(applicationIds);
    _changed();
    try {
      if (selected.isEmpty) {
        throw const AccelerationApiException('EMPTY_SELECTION');
      }
      final freshCatalog = await api.catalog();
      if (!_current(epoch)) return;
      catalog = freshCatalog;
      _selected = selected;
      await core.apply(_builder.build(freshCatalog, selected, null));
      if (!_current(epoch)) return;
      protectionActive = true;
      phase = 'protected';
      _config = null;
      await core.closeApplicationConnections(selected);
      if (!_current(epoch)) return;
      _changed();
      final state = await api.state();
      if (!_current(epoch)) return;
      AccelerationRelease release;
      final pending = state['release'];
      if (pending is Map &&
          pending['status'] == 'pending' &&
          setEquals(
              Set<String>.from(state['application_ids'] as List), selected)) {
        release =
            AccelerationRelease.fromJson(Map<String, dynamic>.from(pending));
      } else {
        final key =
            '${now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
        release = await api.prepare(selected, state['version'] as int, key);
      }
      if (!_current(epoch)) return;
      for (var attempt = 0;
          release.status == 'pending' && attempt < 12;
          attempt++) {
        await delay(const Duration(seconds: 5));
        if (!_current(epoch)) return;
        final next = await api.state();
        if (!_current(epoch)) return;
        final raw = next['release'];
        if (raw is! Map || raw['release_id'] != release.id) {
          throw const AccelerationApiException('RELEASE_CONFLICT');
        }
        release = AccelerationRelease.fromJson(Map<String, dynamic>.from(raw));
      }
      if (release.status != 'ready') {
        throw AccelerationApiException(release.status == 'pending'
            ? 'PREPARATION_PENDING'
            : 'PREPARATION_FAILED');
      }
      final config = await api.config();
      if (!_current(epoch)) return;
      if (config.version != release.version) {
        throw const AccelerationApiException('VERSION_CONFLICT');
      }
      _validate(config);
      await core.apply(_builder.build(freshCatalog, selected, config));
      if (!_current(epoch)) return;
      _config = config;
      protectionActive = true;
      phase = 'connected';
      errorCode = null;
      _schedule();
      _changed();
      try {
        await api.ack(release, 'applied');
      } catch (_) {/* Diagnostics cannot grant/revoke access. */}
    } catch (error) {
      if (!_current(epoch)) return;
      errorCode =
          error is AccelerationApiException ? error.errorCode : 'START_FAILED';
      if (protectionActive && catalog != null) {
        try {
          await core.apply(_builder.build(catalog!, _selected, null));
          if (!_current(epoch)) return;
          await core.closeApplicationConnections(_selected);
        } catch (_) {
          if (_current(epoch)) protectionActive = false;
        }
      }
      if (!_current(epoch)) return;
      _config = null;
      phase = 'failed';
      _changed();
    }
  }

  void _validate(AccelerationConfig config) {
    if (!now().isBefore(config.validUntil)) {
      throw const AccelerationApiException('CONFIG_EXPIRED');
    }
    if (!_selected
        .every((id) => config.applications.any((app) => app['id'] == id))) {
      throw const AccelerationApiException('INCOMPLETE_CONFIGURATION');
    }
  }

  void _schedule() {
    _expiry?.cancel();
    _refreshTimer?.cancel();
    if (_config == null) return;
    _expiry = Timer(_config!.validUntil.difference(now()), () {
      unawaited(_block('CONFIG_EXPIRED'));
    });
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    if (_refreshing || phase != 'connected') return;
    if (_config == null || !now().isBefore(_config!.validUntil)) {
      await _block('CONFIG_EXPIRED');
      return;
    }
    final epoch = _epoch;
    _refreshing = true;
    try {
      final config = await api.config();
      if (!_current(epoch)) return;
      _validate(config);
      if (config.rulesVersion != catalog!.rulesVersion) {
        throw const AccelerationApiException('RULES_CHANGED');
      }
      await core.apply(_builder.build(catalog!, _selected, config));
      if (!_current(epoch)) return;
      _config = config;
      _schedule();
      _changed();
    } catch (error) {
      if (!_current(epoch)) return;
      final temporary = error is AccelerationApiException &&
          (error.errorCode == 'NETWORK_ERROR' ||
              (error.httpStatus ?? 0) >= 500);
      if (!temporary || _config == null || !now().isBefore(_config!.validUntil)) {
        await _block('CONFIG_UNAVAILABLE');
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _block(String reason) async {
    core.invalidatePendingOperations();
    final epoch = ++_epoch;
    _expiry?.cancel();
    _refreshTimer?.cancel();
    _config = null;
    try {
      await core.apply(_builder.build(catalog!, _selected, null));
      if (!_current(epoch)) return;
      await core.closeApplicationConnections(_selected);
      protectionActive = true;
    } catch (_) {
      if (_current(epoch)) protectionActive = false;
    }
    if (!_current(epoch)) return;
    phase = 'failed';
    errorCode = reason;
    _changed();
  }

  Future<void> resume() async {
    if (phase == 'connected') await refresh();
  }

  Future<void> stop() async {
    core.invalidatePendingOperations();
    final epoch = ++_epoch;
    _expiry?.cancel();
    _refreshTimer?.cancel();
    _config = null;
    try {
      await core.apply({});
      if (!_current(epoch)) return;
      await core.closeApplicationConnections(_selected);
      if (!_current(epoch)) return;
      _selected = {};
      protectionActive = false;
      phase = 'idle';
      errorCode = null;
    } catch (_) {
      if (_current(epoch)) {
        phase = 'failed';
        protectionActive = false;
        errorCode = 'STOP_FAILED';
      }
    }
    _changed();
  }

  @override
  void dispose() {
    core.invalidatePendingOperations();
    _disposed = true;
    _epoch++;
    _expiry?.cancel();
    _refreshTimer?.cancel();
    _config = null;
    super.dispose();
  }
}
