import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'stt_settings_service.dart';

class SetupService {
  static const platform = MethodChannel('com.jia_yx.hashtype/ime');

  static Future<bool> isSetupComplete() async {
    // 1. Check Microphone Permission
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) return false;

    // 2. Check IME Enabled
    bool isImeEnabled = false;
    try {
      isImeEnabled = await platform.invokeMethod('isIMEEnabled');
    } catch (e) {
      isImeEnabled = false;
    }
    if (!isImeEnabled) return false;

    // 3. Check STT Configuration (Mandatory)
    final sttService = STTSettingsService();
    final sttSummary = await sttService.getSummary();
    if (sttSummary.needsConfiguration) return false;
    
    return true;
  }
}
