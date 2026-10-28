import 'dart:async';
import 'dart:convert';

final accelerationConfigOverlay = AccelerationConfigOverlay();

class AccelerationConfigOverlay {
  Map<String, dynamic>? value;
  final Set<String> controlHosts = {};
  Future<void> _tail = Future.value();
  bool get active => value != null && value!.isNotEmpty;

  Future<void> serialize(Future<void> Function() operation) {
    final next = _tail.then((_) => operation());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Map<String, dynamic> merge(Map<String, dynamic> base) {
    if (!active) return base;
    final result = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
    final overlay = jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
    final rules = <String>[
      for (final cidr in [
        '127.0.0.0/8',
        '10.0.0.0/8',
        '172.16.0.0/12',
        '192.168.0.0/16'
      ])
        'IP-CIDR,$cidr,DIRECT,no-resolve',
      'IP-CIDR6,::1/128,DIRECT,no-resolve',
      'IP-CIDR6,fc00::/7,DIRECT,no-resolve',
      for (final host in controlHosts)
        if (RegExp(r'^[a-zA-Z0-9.-]+$').hasMatch(host)) 'DOMAIN,$host,DIRECT',
      ...List<String>.from(overlay.remove('rules') as List),
    ];
    result.addAll(overlay);
    result.remove('rules');
    result.remove('proxy-providers');
    result.remove('rule-providers');
    result['rule'] = rules; // Clash.Meta RawConfig: yaml "rules", JSON "rule".
    result['mode'] = 'rule';
    result['find-process-mode'] = 'always';
    result['tun'] = {
      ...Map<String, dynamic>.from(result['tun'] as Map? ?? {}),
      'enable': true,
      'auto-route': true,
      'auto-detect-interface': true,
      'dns-hijack': ['any:53']
    };
    result['dns'] = {
      'enable': true,
      'enhanced-mode': 'fake-ip',
      'fake-ip-range': '198.18.0.1/16',
      'nameserver': ['system://']
    };
    return result;
  }
}
