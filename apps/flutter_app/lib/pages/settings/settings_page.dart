import 'package:flutter/material.dart';
import '../../services/app_settings_service.dart';
import '../../services/setup_service.dart';
import '../../services/stt_settings_service.dart';
import '../../services/llm_settings_service.dart';
import '../../main.dart';
import 'language_selection_page.dart';
import 'language_model_settings_page.dart';
import 'speech_to_text_settings_page.dart';
import 'theme_color_page.dart';
import 'about_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final STTSettingsService _sttSettingsService = STTSettingsService();
  final LLMSettingsService _llmSettingsService = LLMSettingsService();
  bool _llmEnabled = true;
  String _llmSubtitle = 'Loading...';
  String _sttSubtitle = 'Loading...';
  String _languageSubtitle = 'Loading...';
  bool _llmNeedsConfig = false;
  bool _sttNeedsConfig = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final appSettings = AppSettingsService();
    final llmSummary = await _llmSettingsService.getSummary();
    final sttSummary = await _sttSettingsService.getSummary();
    final languageSub = await appSettings.getSelectedLanguageNames();

    if (mounted) {
      setState(() {
        _llmEnabled = llmSummary.enabled;
        _llmSubtitle = llmSummary.subtitle;
        _llmNeedsConfig = llmSummary.needsConfiguration;
        _sttSubtitle = sttSummary.subtitle;
        _sttNeedsConfig = sttSummary.needsConfiguration;
        _languageSubtitle = languageSub;
      });
    }

    // Trigger global setup check to ensure we react to any invalid configuration
    await SetupService().checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: themeManager,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader(context, 'Appearance'),
              _buildSettingTile(
                context,
                icon: Icons.palette_outlined,
                title: 'Theme Color',
                subtitle: 'Customize the keyboard accent color',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ThemeColorPage(),
                    ),
                  );
                },
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: themeManager.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              _buildSettingTile(
                context,
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                subtitle: 'Toggle dark mode',
                trailing: Switch(
                  value: themeManager.themeMode == ThemeMode.dark,
                  onChanged: (v) {
                    themeManager.setThemeMode(
                      v ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Voice & Language'),
              _buildSettingTile(
                context,
                icon: Icons.language_outlined,
                title: 'Input Language',
                subtitle: _languageSubtitle,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LanguageSelectionPage(),
                    ),
                  );
                  _loadSettings();
                },
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'AI Models'),
              _buildSettingTile(
                context,
                icon: Icons.mic_rounded,
                title: 'Speech-to-Text',
                subtitle: _sttSubtitle,
                subtitleColor: _sttNeedsConfig ? Colors.red : null,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SpeechToTextSettingsPage(),
                    ),
                  );
                  _loadSettings();
                },
              ),
              _buildSettingTile(
                context,
                icon: Icons.psychology_rounded,
                title: 'Language Models',
                subtitle: _llmSubtitle,
                subtitleColor: _llmNeedsConfig ? Colors.red : null,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LanguageModelSettingsPage(),
                    ),
                  );
                  // Refresh status when coming back
                  _loadSettings();
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _llmEnabled ? 'On' : 'Off',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'System'),
              _buildSettingTile(
                context,
                icon: Icons.info_outline,
                title: 'About',
                subtitle: 'Version 1.0.0',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AboutPage(),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Color? subtitleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: subtitleColor),
        ),
        trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
