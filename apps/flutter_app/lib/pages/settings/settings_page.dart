import 'package:flutter/material.dart';
import '../../services/app_settings_service.dart';
import '../../main.dart';
import 'language_selection_page.dart';
import 'language_model_settings_page.dart';
import 'speech_to_text_settings_page.dart';
import 'theme_color_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ThemeColorPage()),
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
                    themeManager.setThemeMode(v ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
              ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Voice & Language'),
          _buildSettingTile(
            context,
            icon: Icons.language_outlined,
            title: 'Input Language',
            subtitle: 'English, Chinese...',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LanguageSelectionPage()),
              );
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'AI Models'),
          _buildSettingTile(
            context,
            icon: Icons.mic_rounded,
            title: 'Speech-to-Text',
            subtitle: 'Pick an engine for dictation and recording',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SpeechToTextSettingsPage()),
              );
            },
          ),
          _buildSettingTile(
            context,
            icon: Icons.psychology_rounded,
            title: 'Language Models',
            subtitle: 'Configure cleanup and formatting models',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LanguageModelSettingsPage()),
              );
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'System'),
          _buildSettingTile(
            context,
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'Version 1.0.0',
            onTap: () {},
          ),
          _buildSettingTile(
            context,
            icon: Icons.restart_alt,
            title: 'Reset Setup',
            subtitle: 'Show welcome screen again on next launch',
            onTap: () async {
              final appSettings = AppSettingsService();
              await appSettings.resetSetup();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Setup reset! App will show welcome page on next launch.')),
                );
              }
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
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
