import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/src/core/http/http_service.dart';
import 'package:flutter_xboard_sdk/src/panels/xboard/apis/xboard_acceleration_api.dart';
import 'package:flutter_xboard_sdk/src/api/models/acceleration_models.dart';

class _Adapter implements HttpClientAdapter {
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancel) async {
    request = options;
    return ResponseBody.fromString(
        jsonEncode({
          'status': 'fail',
          'error_code': 'REALNAME_REQUIRED',
          'data': null,
          'message': 'REALNAME_REQUIRED'
        }),
        403,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('prepare preserves stable business error and idempotency header',
      () async {
    final http = await HttpService.create('https://panel.example.test');
    final adapter = _Adapter();
    http.dio.httpClientAdapter = adapter;
    final api = XBoardAccelerationApi(http);
    await expectLater(
        api.prepare({'demo'}, 0, 'fixed-test-key-001'),
        throwsA(isA<AccelerationApiException>()
            .having((e) => e.errorCode, 'error code', 'REALNAME_REQUIRED')));
    expect(adapter.request!.headers['Idempotency-Key'], 'fixed-test-key-001');
    expect(adapter.request!.data['application_ids'], ['demo']);
    http.dispose();
  });
  test(
      'shared fixture validates configuration and rejects absent lane references',
      () {
    final fixture = jsonDecode(
            File('test/fixtures/acceleration-v1.json').readAsStringSync())
        as Map<String, dynamic>;
    final config = AccelerationConfig.fromJson(fixture['config']);
    expect(config.version, 1);
    final broken =
        jsonDecode(jsonEncode(fixture['config'])) as Map<String, dynamic>;
    broken['mihomo']['proxies'] = [];
    expect(() => AccelerationConfig.fromJson(broken), throwsFormatException);
  });
}
