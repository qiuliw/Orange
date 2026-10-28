import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/src/api/interfaces/user_api.dart';

void main() {
  test('current develop realName contract retains verified status and epoch',
      () {
    final fixture = jsonDecode(
            File('test/fixtures/acceleration-v1.json').readAsStringSync())
        as Map<String, dynamic>;
    final data = fixture['realname_status']['data'] as Map<String, dynamic>;
    final status = RealNameStatus.fromJson(data);
    expect(status.required, isTrue);
    expect(status.verified, isTrue);
    expect(status.verifiedAt, 1793145600);
  });
}
