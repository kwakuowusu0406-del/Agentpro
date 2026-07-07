import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'storage_service.dart';

/// Biometric authentication service.
///
/// CRITICAL SECURITY RULE:
/// Biometrics are used ONLY to unlock the app (restore session).
/// They are NEVER used as a substitute for or replacement of a MoMo PIN.
/// The MoMo PIN is always entered by the user on the official network USSD screen.
class BiometricService {
  static final _auth = LocalAuthentication();

  /// Check if biometric hardware is available and enrolled
  static Future<BiometricAvailability> checkAvailability() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return BiometricAvailability.notAvailable;

      final isDeviceSupported = await _auth.isDeviceSupported();
      if (!isDeviceSupported) return BiometricAvailability.notAvailable;

      final availableBiometrics = await _auth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) return BiometricAvailability.notEnrolled;

      return BiometricAvailability.available;
    } on PlatformException {
      return BiometricAvailability.notAvailable;
    }
  }

  /// Get list of available biometric types
  static Future<List<BiometricType>> getAvailableTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Authenticate using biometrics to UNLOCK THE APP.
  /// This restores the user's existing session — it does NOT collect a MoMo PIN.
  static Future<BiometricResult> authenticateToUnlock() async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Authenticate to open Agent Pro Ghana',
        options: const AuthenticationOptions(
          biometricOnly: false, // Allow PIN/pattern as fallback
          stickyAuth: true,
          sensitiveTransaction: false,
        ),
      );

      return authenticated
          ? BiometricResult.success
          : BiometricResult.cancelled;
    } on PlatformException catch (e) {
      switch (e.code) {
        case auth_error.notAvailable:
          return BiometricResult.notAvailable;
        case auth_error.notEnrolled:
          return BiometricResult.notEnrolled;
        case auth_error.lockedOut:
          return BiometricResult.lockedOut;
        case auth_error.permanentlyLockedOut:
          return BiometricResult.permanentlyLockedOut;
        default:
          return BiometricResult.error;
      }
    }
  }

  /// Enable biometric unlock (requires one successful authentication first)
  static Future<bool> enableBiometric() async {
    final result = await authenticateToUnlock();
    if (result != BiometricResult.success) return false;
    await StorageService.setBiometricEnabled(true);
    return true;
  }

  /// Disable biometric unlock
  static Future<void> disableBiometric() async {
    await StorageService.setBiometricEnabled(false);
  }

  /// Check if biometric unlock is enabled by the user
  static Future<bool> isBiometricEnabled() async {
    final availability = await checkAvailability();
    if (availability != BiometricAvailability.available) return false;
    return StorageService.isBiometricEnabled();
  }

  /// Get human-readable name for available biometric type
  static Future<String> getBiometricLabel() async {
    final types = await getAvailableTypes();
    if (types.contains(BiometricType.face)) return 'Face ID';
    if (types.contains(BiometricType.fingerprint)) return 'Fingerprint';
    if (types.contains(BiometricType.iris)) return 'Iris';
    return 'Biometrics';
  }
}

enum BiometricAvailability { available, notAvailable, notEnrolled }

enum BiometricResult {
  success,
  cancelled,
  notAvailable,
  notEnrolled,
  lockedOut,
  permanentlyLockedOut,
  error,
}
