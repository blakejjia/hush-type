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

  bool _hasMicPermission = false;
  bool get hasMicPermission => _hasMicPermission;

  bool _isImeEnabled = false;
  bool get isImeEnabled => _isImeEnabled;

  bool _isSttConfigured = false;
  bool get isSttConfigured => _isSttConfigured;

  Future<bool> checkStatus() async {
    // 1. Check Microphone Permission
    final micStatus = await Permission.microphone.status;
    _hasMicPermission = micStatus.isGranted;

    // 2. Check IME Enabled
    try {
      _isImeEnabled = await platform.invokeMethod('isIMEEnabled');
    } catch (e) {
      _isImeEnabled = false;
    }

    // 3. Check STT Configuration (Mandatory)
    final sttService = STTSettingsService();
    final sttSummary = await sttService.getSummary();
    _isSttConfigured = !sttSummary.needsConfiguration;
    
    _isComplete = _hasMicPermission && _isSttConfigured;
    notifyListeners();
    return _isComplete;
  }

  // Static helper for one-off checks
  static Future<bool> isSetupComplete() async {
    return await SetupService().checkStatus();
  }
}
