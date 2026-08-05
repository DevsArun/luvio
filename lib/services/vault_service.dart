import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';

import 'preferences_service.dart';

/// Handles PIN hashing/verification and biometric authentication for the
/// Private Vault. PINs are stored as salted SHA-256 digests — never in
/// plaintext.
class VaultService {
  VaultService(this._prefs);

  final PreferencesService _prefs;
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool get hasPin => (_prefs.getString(PrefKeys.vaultPinHash) ?? '').isNotEmpty;

  bool get biometricEnabled => _prefs.getBool(PrefKeys.vaultBiometric, true);

  Future<void> setBiometricEnabled(bool value) =>
      _prefs.setBool(PrefKeys.vaultBiometric, value);

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt::$pin::luvio-player')).toString();

  Future<void> setPin(String pin) async {
    final salt = List.generate(16, (_) => Random.secure().nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    await _prefs.setString(PrefKeys.vaultPinSalt, salt);
    await _prefs.setString(PrefKeys.vaultPinHash, _hash(pin, salt));
  }

  bool verifyPin(String pin) {
    final salt = _prefs.getString(PrefKeys.vaultPinSalt) ?? '';
    final stored = _prefs.getString(PrefKeys.vaultPinHash) ?? '';
    if (salt.isEmpty || stored.isEmpty) return false;
    return _hash(pin, salt) == stored;
  }

  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access hidden media',
        options: AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // --- Hidden paths -----------------------------------------------------------
  List<String> get vaultPaths => _prefs.getStringList(PrefKeys.vaultPaths);

  Future<void> addToVault(String path) async {
    final paths = [...vaultPaths];
    if (!paths.contains(path)) paths.add(path);
    await _prefs.setStringList(PrefKeys.vaultPaths, paths);
  }

  Future<void> removeFromVault(String path) async {
    final paths = [...vaultPaths]..remove(path);
    await _prefs.setStringList(PrefKeys.vaultPaths, paths);
  }
}
