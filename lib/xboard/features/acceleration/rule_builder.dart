import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

class AccelerationRuleBuilder {
  static const _browsers = {
    'chrome.exe',
    'msedge.exe',
    'firefox.exe',
    'brave.exe',
    'opera.exe',
    'safari'
  };

  Map<String, dynamic> build(AccelerationCatalog catalog, Set<String> selected,
      AccelerationConfig? config) {
    if (config != null && config.rulesVersion != catalog.rulesVersion) {
      throw const FormatException('Rules version mismatch');
    }
    if (!selected
        .every((id) => catalog.applications.any((app) => app.id == id))) {
      throw const FormatException('Unknown application');
    }
    final apps =
        catalog.applications.where((a) => selected.contains(a.id)).toList()
          ..sort((a, b) {
            final order = b.priority.compareTo(a.priority);
            return order != 0 ? order : a.id.compareTo(b.id);
          });
    final rules = <String>[];
    final groups = <Map<String, dynamic>>[];
    final targets = <String, String>{};
    for (final app in apps) {
      final bindings = config?.applications
          .where((binding) => binding['id'] == app.id)
          .toList();
      final names = bindings != null && bindings.isNotEmpty
          ? List<String>.from(bindings.first['proxy_names'] as List)
          : <String>[];
      final target = names.isEmpty ? 'REJECT' : 'accel-app-${app.id}';
      targets[app.id] = target;
      if (names.isNotEmpty) {
        groups.add({'name': target, 'type': 'select', 'proxies': names});
      }
    }
    // All domain rules precede every broad process rule, including other apps.
    for (final app in apps) {
      for (final domain in app.domains) {
        rules.add('DOMAIN-SUFFIX,$domain,${targets[app.id]}');
      }
    }
    for (final app in apps) {
      for (final process in app.processNames) {
        if (!_browsers.contains(process.toLowerCase())) {
          rules.add('PROCESS-NAME,$process,${targets[app.id]}');
        }
      }
    }
    return {
      'mode': 'rule',
      'find-process-mode': 'always',
      'proxies': config?.proxies ?? <Map<String, dynamic>>[],
      'proxy-groups': groups,
      'rules': [...rules, 'MATCH,DIRECT']
    };
  }
}
