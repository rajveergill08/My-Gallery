import 'package:photo_manager/photo_manager.dart';

class PermissionService {
  static const option = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.common,
      mediaLocation: false,
    ),
  );

  Future<PermissionState> current() =>
      PhotoManager.getPermissionState(requestOption: option);
  Future<PermissionState> request() =>
      PhotoManager.requestPermissionExtend(requestOption: option);
  Future<void> openSettings() => PhotoManager.openSetting();
  Future<void> manageLimitedSelection() =>
      PhotoManager.presentLimited(type: RequestType.common);
}
