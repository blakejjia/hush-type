import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static const String _isSetupCompleteKey = 'isSetupComplete';

  Future<void> resetSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isSetupCompleteKey);
  }
}
