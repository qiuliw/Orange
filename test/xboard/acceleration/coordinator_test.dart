import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/features/acceleration/coordinator.dart';
import 'package:fl_clash/xboard/features/acceleration/core_config_port.dart';

class FakeApi implements AccelerationApi {
  final List<String> events;
  final Map<String, dynamic> fixture;
  Completer<AccelerationRelease>? waiting;
  bool fail = false;
  FakeApi(this.events, this.fixture);
  @override
  Future<AccelerationCatalog> catalog() async =>
      AccelerationCatalog.fromJson(fixture['catalog']);
  @override
  Future<Map<String, dynamic>> state() async =>
      {'version': 0, 'application_ids': [], 'release': null};
  @override
  Future<int> savePreferences(Set<String> ids, int version) async =>
      version + 1;
  @override
  Future<AccelerationRelease> prepare(
      Set<String> ids, int version, String key) async {
    events.add('api:prepare');
    if (fail) throw const AccelerationApiException('NO_CAPACITY', 503);
    return waiting?.future ??
        Future.value(AccelerationRelease.fromJson(
            {'release_id': 'r', 'version': 1, 'status': 'ready'}));
  }

  @override
  Future<AccelerationConfig> config() async =>
      AccelerationConfig.fromJson(fixture['config']);
  @override
  Future<void> ack(AccelerationRelease release, String result,
      {String? errorCode}) async {}
  @override
  Future<void> reportMeasurements(String entranceId, List<int> samples) async {}
}

class FakeCore implements CoreConfigPort {
  final List<String> events;
  Map<String, dynamic> last = {};
  bool deny = false;
  FakeCore(this.events);
  @override
  Future<void> apply(Map<String, dynamic> overlay) async {
    if (deny) throw StateError('TUN unavailable');
    last = overlay;
    events.add(overlay.isEmpty
        ? 'core:stop'
        : overlay['rules'][0].endsWith(',REJECT')
            ? 'core:reject'
            : 'core:connect');
  }

  @override
  Future<void> closeApplicationConnections(Set<String> ids) async {
    events.add('core:close');
  }
}

class DelayedCore extends FakeCore {
  Completer<void>? nextReject;
  DelayedCore(super.events);
  @override
  Future<void> apply(Map<String, dynamic> overlay) {
    final delayed = nextReject;
    if (delayed != null &&
        overlay.isNotEmpty &&
        overlay['rules'][0].endsWith(',REJECT')) {
      nextReject = null;
      return delayed.future;
    }
    return super.apply(overlay);
  }
}

void main() {
  final fixture =
      jsonDecode(File('test/fixtures/acceleration-v1.json').readAsStringSync())
          as Map<String, dynamic>;
  late List<String> events;
  late FakeApi api;
  late FakeCore core;
  late AccelerationCoordinator coordinator;
  setUp(() {
    events = [];
    api = FakeApi(events, fixture);
    core = FakeCore(events);
    coordinator = AccelerationCoordinator(
        api: api, core: core, now: () => DateTime.utc(2026, 10, 28));
  });
  tearDown(() => coordinator.dispose());
  test('reject protection precedes API preparation and successful connection',
      () async {
    await coordinator.start({'demo'});
    expect(
        events.indexOf('core:reject'), lessThan(events.indexOf('api:prepare')));
    expect(coordinator.phase, 'connected');
    expect(coordinator.protectionActive, isTrue);
  });
  test('network failure keeps selected application rejected', () async {
    api.fail = true;
    await coordinator.start({'demo'});
    expect(coordinator.protectionActive, isTrue);
    expect(core.last['rules'][0], endsWith(',REJECT'));
    expect(coordinator.phase, 'failed');
  });
  test('permission failure does not claim protection or call prepare',
      () async {
    core.deny = true;
    await coordinator.start({'demo'});
    expect(coordinator.protectionActive, isFalse);
    expect(events, isNot(contains('api:prepare')));
  });
  test('stop invalidates late asynchronous results', () async {
    api.waiting = Completer<AccelerationRelease>();
    final starting = coordinator.start({'demo'});
    while (!events.contains('api:prepare')) {
      await Future<void>.delayed(Duration.zero);
    }
    await coordinator.stop();
    api.waiting!.complete(AccelerationRelease.fromJson(
        {'release_id': 'r', 'version': 1, 'status': 'ready'}));
    await starting;
    expect(coordinator.phase, 'idle');
    expect(events.last, 'core:close');
    expect(events, isNot(contains('core:connect')));
  });
  test('resume after expiry blocks existing connections', () async {
    var time = DateTime.utc(2026, 10, 28);
    coordinator.dispose();
    coordinator =
        AccelerationCoordinator(api: api, core: core, now: () => time);
    await coordinator.start({'demo'});
    time = DateTime.utc(2026, 10, 30);
    await coordinator.resume();
    expect(coordinator.phase, 'failed');
    expect(coordinator.protectionActive, isTrue);
    expect(core.last['rules'][0], endsWith(',REJECT'));
  });
  test('late failure of an expired session cannot clear newer protection',
      () async {
    var time = DateTime.utc(2026, 10, 28);
    final delayedCore = DelayedCore(events);
    coordinator.dispose();
    coordinator =
        AccelerationCoordinator(api: api, core: delayedCore, now: () => time);
    await coordinator.start({'demo'});
    final pending = Completer<void>();
    delayedCore.nextReject = pending;
    time = DateTime.utc(2026, 10, 30);
    final expiring = coordinator.resume();
    time = DateTime.utc(2026, 10, 28);
    await coordinator.start({'demo'});
    pending.completeError(StateError('old apply failed'));
    await expiring;
    expect(coordinator.phase, 'connected');
    expect(coordinator.protectionActive, isTrue);
  });
}
