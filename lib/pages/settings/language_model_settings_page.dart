import 'package:flutter/material.dart';
import 'widgets/language_model_settings_list.dart';

class LanguageModelSettingsPage extends StatelessWidget {
  const LanguageModelSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Language Models', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: const LanguageModelSettingsList(title: 'Cleanup'),
    );
  }
}
