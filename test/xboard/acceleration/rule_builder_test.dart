import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/src/api/models/acceleration_models.dart';
import 'package:fl_clash/xboard/features/acceleration/rule_builder.dart';

void main() {
  final fixture =
      jsonDecode(File('test/fixtures/acceleration-v1.json').readAsStringSync())
          as Map<String, dynamic>;
  test('domain precedes process and unselected traffic stays direct', () {
    final catalog = AccelerationCatalog.fromJson(fixture['catalog']);
    final config = AccelerationConfig.fromJson(fixture['config']);
    final map = AccelerationRuleBuilder().build(catalog, {'demo'}, config);
    expect(map['mode'], 'rule');
    expect(map['rules'], [
      'DOMAIN-SUFFIX,service.example.test,accel-app-demo',
      'PROCESS-NAME,demo.exe,accel-app-demo',
      'MATCH,DIRECT'
    ]);
    expect(map['proxy-groups'][0]['proxies'], ['accel-lane-1']);
  });
  test(
      'selected applications are rejected before a usable configuration exists',
      () {
    final catalog = AccelerationCatalog.fromJson(fixture['catalog']);
    final map = AccelerationRuleBuilder().build(catalog, {'demo'}, null);
    expect(map['rules'][0], 'DOMAIN-SUFFIX,service.example.test,REJECT');
    expect(map['rules'][1], 'PROCESS-NAME,demo.exe,REJECT');
    expect(map['rules'].last, 'MATCH,DIRECT');
  });
  test('unknown schema or unsafe rules fail instead of accepting remote code',
      () {
    expect(
        () => AccelerationConfig.fromJson(
            {...fixture['config'], 'schema_version': 9}),
        throwsFormatException);
    final raw =
        jsonDecode(jsonEncode(fixture['catalog'])) as Map<String, dynamic>;
    raw['applications'][0]['domains'] = ['example.test,DIRECT'];
    expect(() => AccelerationCatalog.fromJson(raw), throwsFormatException);
  });
}
