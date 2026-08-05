import 'package:flutter/foundation.dart';

import '../services/vault_service.dart';
import 'library_provider.dart';

enum VaultAuthPhase { idle, scanning, success, failure }

/// Session state for the Private Vault (lock status + auth flow).
class VaultProvider extends ChangeNotifier {
  VaultProvider(this.service, this._library);

  final VaultService service;
  final LibraryProvider _library;

  bool unlocked = false;
  VaultAuthPhase phase = VaultAuthPhase.idle;
  String enteredPin = '';
  String? errorMessage;

  bool get hasPin => service.hasPin;

  void appendPinDigit(String digit) {
    if (enteredPin.length >= 4) return;
    enteredPin += digit;
    errorMessage = null;
    notifyListeners();
    if (enteredPin.length == 4) _verifyEnteredPin();
  }

  void deletePinDigit() {
    if (enteredPin.isEmpty) return;
    enteredPin = enteredPin.substring(0, enteredPin.length - 1);
    notifyListeners();
  }

  void _verifyEnteredPin() {
    if (service.verifyPin(enteredPin)) {
      phase = VaultAuthPhase.success;
      notifyListeners();
      Future.delayed(Duration(milliseconds: 600), () {
        unlocked = true;
        phase = VaultAuthPhase.idle;
        enteredPin = '';
        notifyListeners();
      });
    } else {
      phase = VaultAuthPhase.failure;
      errorMessage = 'Incorrect PIN. Try again.';
      notifyListeners();
      Future.delayed(Duration(milliseconds: 700), () {
        enteredPin = '';
        phase = VaultAuthPhase.idle;
        notifyListeners();
      });
    }
  }

  Future<void> authenticateWithBiometrics() async {
    if (!service.biometricEnabled) return;
    if (!await service.canUseBiometrics()) return;
    phase = VaultAuthPhase.scanning;
    notifyListeners();
    final ok = await service.authenticateBiometric();
    if (ok) {
      phase = VaultAuthPhase.success;
      notifyListeners();
      await Future<void>.delayed(Duration(milliseconds: 600));
      unlocked = true;
      phase = VaultAuthPhase.idle;
    } else {
      phase = VaultAuthPhase.failure;
      errorMessage = 'Authentication failed';
      notifyListeners();
      await Future<void>.delayed(Duration(milliseconds: 900));
      phase = VaultAuthPhase.idle;
    }
    notifyListeners();
  }

  void lock() {
    unlocked = false;
    enteredPin = '';
    phase = VaultAuthPhase.idle;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> setPin(String pin) async {
    await service.setPin(pin);
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool value) async {
    await service.setBiometricEnabled(value);
    notifyListeners();
  }

  bool get biometricEnabled => service.biometricEnabled;

  Future<void> hideVideo(String path) async {
    await service.addToVault(path);
    _library.vaultChanged();
    notifyListeners();
  }

  Future<void> restoreVideo(String path) async {
    await service.removeFromVault(path);
    _library.vaultChanged();
    notifyListeners();
  }
}
