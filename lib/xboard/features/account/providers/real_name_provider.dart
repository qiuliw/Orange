import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

class RealNameState {
  final bool required;
  final bool verified;
  final String? realName;
  final String? idNumberMask;
  final int? verifiedAt;
  final bool loading;
  final String? error;

  const RealNameState({
    this.required = false,
    this.verified = false,
    this.realName,
    this.idNumberMask,
    this.verifiedAt,
    this.loading = false,
    this.error,
  });

  RealNameState copyWith({
    bool? required,
    bool? verified,
    String? realName,
    String? idNumberMask,
    int? verifiedAt,
    bool? loading,
    String? error,
  }) {
    return RealNameState(
      required: required ?? this.required,
      verified: verified ?? this.verified,
      realName: realName ?? this.realName,
      idNumberMask: idNumberMask ?? this.idNumberMask,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class RealNameNotifier extends StateNotifier<RealNameState> {
  RealNameNotifier() : super(const RealNameState());

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final status = await XBoardSDK.instance.user.getRealNameStatus();
      state = RealNameState(
        required: status.required,
        verified: status.verified,
        realName: status.realName,
        idNumberMask: status.idNumberMask,
        verifiedAt: status.verifiedAt,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

final realNameProvider =
    StateNotifierProvider<RealNameNotifier, RealNameState>((ref) {
  return RealNameNotifier();
});
