import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'stt_settings_service.dart';

class SetupService extends ChangeNotifier {
  static const platform = MethodChannel('com.jia_yx.hashtype/ime');
  
  static final SetupService _instance = SetupService._internal();
  factory SetupService() => _instance;
  SetupService._internal();

  bool _isComplete = false;
  bool get isComplete => _isComplete;

  Future<bool> checkStatus() async {
    // 1. Check Microphone Permission
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      _updateComplete(false);
      return false;
    }

    // 2. Check IME Enabled
    bool isImeEnabled = false;
    try {
      isImeEnabled = await platform.invokeMethod('isIMEEnabled');
    } catch (e) {
      isImeEnabled = false;
    }
    if (!isImeEnabled) {
      _updateComplete(false);
      return false;
    }

    // 3. Check STT Configuration (Mandatory)
    final sttService = STTSettingsService();
    final sttSummary = await sttService.getSummary();
    if (sttSummary.needsConfiguration) {
      _updateComplete(false);
      return false;
    }
    
    _updateComplete(true);
    return true;
  }

  void _updateComplete(bool value) {
    if (_isComplete != value) {
      _isComplete = value;
      notifyListeners();
    }
  }

  // Static helper for one-off checks
  static Future<bool> isSetupComplete() async {
    return await SetupService().checkStatus();
  }
}
