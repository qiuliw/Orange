import 'dart:io';

class EntranceProbe {
  final Future<int?> Function(String, int) sample;
  EntranceProbe({Future<int?> Function(String, int)? sample})
      : sample = sample ?? _connect;

  static Future<int?> _connect(String host, int port) async {
    Socket? socket;
    final clock = Stopwatch()..start();
    try {
      socket =
          await Socket.connect(host, port, timeout: const Duration(seconds: 3));
      return clock.elapsedMilliseconds;
    } catch (_) {
      return null;
    } finally {
      socket?.destroy();
    }
  }

  Future<Duration?> measure(String host, int port) async {
    final samples = <int>[];
    for (var i = 0; i < 3; i++) {
      try {
        final ms = await sample(host, port)
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
        if (ms != null && ms >= 0 && ms <= 3000) samples.add(ms);
      } catch (_) {/* A failed sample does not become a fake latency. */}
    }
    if (samples.isEmpty) return null;
    samples.sort();
    final micros = samples.length == 2
        ? ((samples[0] + samples[1]) * 500)
        : samples[samples.length ~/ 2] * 1000;
    return Duration(microseconds: micros);
  }
}
