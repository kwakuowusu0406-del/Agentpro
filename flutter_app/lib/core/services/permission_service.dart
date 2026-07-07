import 'package:permission_handler/permission_handler.dart';

/// Manages runtime permission requests required for USSD automation.
///
/// Android 6.0+ requires these to be granted at runtime, not just
/// declared in the manifest:
/// - [Permission.phone] covers both READ_PHONE_STATE (SIM detection)
///   and CALL_PHONE (dialing USSD codes)
class PermissionService {
  /// Check whether all telephony permissions needed for USSD
  /// automation are currently granted.
  static Future<bool> hasTelephonyPermissions() async {
    final status = await Permission.phone.status;
    return status.isGranted;
  }

  /// Request telephony permissions, showing the system dialog if needed.
  /// Returns the resulting [PermissionResult].
  static Future<PermissionResult> requestTelephonyPermissions() async {
    final status = await Permission.phone.status;

    if (status.isGranted) {
      return PermissionResult.granted;
    }

    if (status.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    }

    final result = await Permission.phone.request();

    if (result.isGranted) return PermissionResult.granted;
    if (result.isPermanentlyDenied) return PermissionResult.permanentlyDenied;
    return PermissionResult.denied;
  }

  /// Open the app's system settings page so the user can manually
  /// grant a permanently-denied permission.
  static Future<void> openSettings() async {
    await openAppSettings();
  }
}

enum PermissionResult { granted, denied, permanentlyDenied }
