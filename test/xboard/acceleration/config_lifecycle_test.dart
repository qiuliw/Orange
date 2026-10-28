import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/xboard/features/acceleration/config_overlay.dart';
import 'package:fl_clash/xboard/features/acceleration/rule_builder.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

void main() {
  test('authorization completion after stop cannot mutate the core overlay',
      () async {
    final store = AccelerationConfigOverlay();
    final authorization = Completer<void>();
    final oldStart = store.guardedApply(
      authorize: (_) async {
        await authorization.future;
      },
      mutate: (_) async {
        store.value = {
          'rules': ['MATCH,REJECT']
        };
      },
    );
    store.invalidatePendingOperations();
    await store.guardedApply(
        authorize: (_) async {},
        mutate: (_) async {
          store.value = null;
        });
    authorization.complete();
    await oldStart;
    expect(store.active, isFalse);
  });
  test('export the compiled configuration for the pinned Go core parser', () {
    final fixture = jsonDecode(
            File('test/fixtures/acceleration-v1.json').readAsStringSync())
        as Map<String, dynamic>;
    final store = AccelerationConfigOverlay();
    store.value = AccelerationRuleBuilder().build(
        AccelerationCatalog.fromJson(fixture['catalog']),
        {'demo'},
        AccelerationConfig.fromJson(fixture['config']));
    final result = store.merge({});
    File('.dart_tool/acceleration-core-config.json')
        .writeAsStringSync(jsonEncode(result));
    expect(result['rule'].last, 'MATCH,DIRECT');
  });
  test('overlay wins over legacy mode and uses the cores JSON rule key', () {
    final store = AccelerationConfigOverlay();
    store.value = {
      'rules': ['DOMAIN,app.example.test,REJECT', 'MATCH,DIRECT'],
      'proxies': [],
      'proxy-groups': []
    };
    final merged = store.merge({
      'mode': 'global',
      'rule': ['MATCH,old'],
      'tun': {'enable': false},
      'mixed-port': 7890
    });
    expect(merged['mode'], 'rule');
    expect(merged['tun']['enable'], isTrue);
    expect(merged['rule'], contains('DOMAIN,app.example.test,REJECT'));
    expect(merged['rules'], isNull);
    expect(merged['mixed-port'], 7890);
    expect(merged['rule'].last, 'MATCH,DIRECT');
  });
  test(
      'protection remains available without a selected profile and on subscription refresh',
      () {
    final store = AccelerationConfigOverlay();
    store.value = {
      'rules': ['MATCH,REJECT'],
      'proxies': [],
      'proxy-groups': []
    };
    expect(store.merge({})['rule'].last, 'MATCH,REJECT');
    expect(
        store.merge({
          'rule': ['MATCH,old']
        })['rule'].last,
        'MATCH,REJECT');
  });
  test('serialized updates continue after a failed operation', () async {
    final store = AccelerationConfigOverlay();
    final order = <int>[];
    final first = store.serialize(() async {
      order.add(1);
      throw StateError('expected');
    });
    final second = store.serialize(() async {
      order.add(2);
    });
    await expectLater(first, throwsStateError);
    await second;
    expect(order, [1, 2]);
  });
}
