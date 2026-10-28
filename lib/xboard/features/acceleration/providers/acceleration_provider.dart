import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/state.dart';
import '../../auth/providers/xboard_user_provider.dart';
import '../config_overlay.dart';
import '../coordinator.dart';
import '../core_config_port.dart';

class _CorePort implements CoreConfigPort {
  @override
  void invalidatePendingOperations() =>
      accelerationConfigOverlay.invalidatePendingOperations();
  @override
  Future<void> apply(Map<String, dynamic> overlay) =>
      globalState.appController.applyAccelerationOverlay(overlay);
  @override
  Future<void> closeApplicationConnections(Set<String> ids) async {
    final closed =
        await Future<bool>.sync(clashCore.clashInterface.closeConnections);
    if (!closed) throw StateError('Could not close previous connections');
  }
}

class _ResumeObserver extends WidgetsBindingObserver {
  final AccelerationCoordinator coordinator;
  _ResumeObserver(this.coordinator);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(coordinator.resume());
  }
}

final accelerationCoordinatorProvider =
    ChangeNotifierProvider<AccelerationCoordinator>((ref) {
  final sdk = XBoardSDK.instance;
  accelerationConfigOverlay.controlHosts
    ..clear()
    ..addAll([if (sdk.baseUrl != null) Uri.parse(sdk.baseUrl!).host]);
  final coordinator =
      AccelerationCoordinator(api: sdk.acceleration, core: _CorePort());
  final observer = _ResumeObserver(coordinator);
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
  ref.listen(xboardUserAuthProvider, (previous, next) {
    if (previous?.isAuthenticated == true &&
        (!next.isAuthenticated || previous?.email != next.email)) {
      unawaited(coordinator.stop());
    }
  });
  return coordinator;
});
