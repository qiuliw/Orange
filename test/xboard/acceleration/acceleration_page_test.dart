import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/xboard/features/acceleration/coordinator.dart';
import 'package:fl_clash/xboard/features/acceleration/pages/acceleration_page.dart';
import 'coordinator_test.dart' show FakeApi, FakeCore;

void main() {
  testWidgets(
      'application page labels entrance latency and a permission failure accurately',
      (tester) async {
    final fixture = jsonDecode(
            File('test/fixtures/acceleration-v1.json').readAsStringSync())
        as Map<String, dynamic>;
    final events = <String>[];
    final core = FakeCore(events)..deny = true;
    final coordinator = AccelerationCoordinator(
        api: FakeApi(events, fixture),
        core: core,
        now: () => DateTime.utc(2026, 10, 28));
    await tester.pumpWidget(
        MaterialApp(home: AccelerationPage(coordinator: coordinator)));
    await tester.pumpAndSettle();
    expect(find.text('Demo'), findsOneWidget);
    expect(find.text('入口连接延迟：暂无数据'), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('开启加速'));
    await tester.pumpAndSettle();
    expect(find.textContaining('当前使用系统网络'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    coordinator.dispose();
  });
}
