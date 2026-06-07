import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/services/app_update_service.dart';
import '../../data/services/script_service_provider.dart';
import '../../domain/models/app_update_info.dart';

enum AppUpdateStatus { idle, checking, updateAvailable, noUpdate, checkFailed }

class AppUpdateState {
  final AppUpdateStatus status;
  final AppUpdateInfo? updateInfo;
  final String? errorMessage;

  const AppUpdateState({
    this.status = AppUpdateStatus.idle,
    this.updateInfo,
    this.errorMessage,
  });

  bool get isChecking {
    return status == AppUpdateStatus.checking;
  }
}

class AppUpdateViewModel extends Notifier<AppUpdateState> {
  @override
  AppUpdateState build() {
    return const AppUpdateState();
  }

  Future<AppUpdateState> checkForUpdates({bool silent = false}) async {
    if (!silent) {
      state = const AppUpdateState(status: AppUpdateStatus.checking);
    }

    final result = await ref.read(appUpdateServiceProvider).checkForUpdates();
    final nextState = _stateFromResult(result);
    state = nextState;
    return nextState;
  }

  Future<bool> openDownload() async {
    final updateInfo = state.updateInfo;
    if (updateInfo == null) return false;

    return launchUrl(
      updateInfo.downloadUrl,
      mode: LaunchMode.externalApplication,
    );
  }

  AppUpdateState _stateFromResult(AppUpdateCheck result) {
    final updateInfo = result.updateInfo;
    if (updateInfo != null) {
      return AppUpdateState(
        status: AppUpdateStatus.updateAvailable,
        updateInfo: updateInfo,
      );
    }

    if (result.failed) {
      return AppUpdateState(
        status: AppUpdateStatus.checkFailed,
        errorMessage: result.errorMessage,
      );
    }

    return const AppUpdateState(status: AppUpdateStatus.noUpdate);
  }
}

final appUpdateViewModelProvider =
    NotifierProvider<AppUpdateViewModel, AppUpdateState>(
      AppUpdateViewModel.new,
    );
