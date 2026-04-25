import 'package:flutter/material.dart';
import '../../services/app_settings_service.dart';

class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  final AppSettingsService _settingsService = AppSettingsService();
  final List<Map<String, String>> _languages = [
    {'name': 'English (US)', 'code': 'en_US'},
    {'name': 'Chinese (Simplified)', 'code': 'zh_CN'},
    {'name': 'Chinese (Traditional)', 'code': 'zh_TW'},
    {'name': 'Spanish', 'code': 'es_ES'},
    {'name': 'French', 'code': 'fr_FR'},
    {'name': 'German', 'code': 'de_DE'},
    {'name': 'Japanese', 'code': 'ja_JP'},
    {'name': 'Korean', 'code': 'ko_KR'},
    {'name': 'Russian', 'code': 'ru_RU'},
    {'name': 'Portuguese', 'code': 'pt_PT'},
  ];

  Set<String> _selectedLanguages = {'en_US'};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final languages = await _settingsService.getSelectedLanguages();
    if (mounted) {
      setState(() {
        _selectedLanguages = languages.toSet();
      });
    }
  }

  void _saveSettings() {
    _settingsService.setSelectedLanguages(_selectedLanguages.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Languages', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _languages.length,
        itemBuilder: (context, index) {
          final lang = _languages[index];
          final isSelected = _selectedLanguages.contains(lang['code']);
          
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: CheckboxListTile(
              title: Text(lang['name']!, style: const TextStyle(fontWeight: FontWeight.w500)),
              value: isSelected,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedLanguages.add(lang['code']!);
                  } else {
                    if (_selectedLanguages.length > 1) {
                      _selectedLanguages.remove(lang['code']!);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('At least one language must be selected')),
                      );
                    }
                  }
                  _saveSettings();
                });
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
        },
      ),
    );
  }
}
