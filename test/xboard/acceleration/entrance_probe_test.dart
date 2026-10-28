import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/xboard/features/acceleration/entrance_probe.dart';

void main() {
  test('three samples use median and partial failure uses successful mean',
      () async {
    var samples = <int?>[30, 10, 20];
    final probe = EntranceProbe(sample: (_, __) async => samples.removeAt(0));
    expect(await probe.measure('entry.example.test', 443),
        const Duration(milliseconds: 20));
    samples = [null, 12, 28];
    expect(await probe.measure('entry.example.test', 443),
        const Duration(milliseconds: 20));
    samples = [null, null, null];
    expect(await probe.measure('entry.example.test', 443), isNull);
  });
}
