import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'floating_mic_customize_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with WidgetsBindingObserver {
  static const _platform = MethodChannel('com.jia_yx.hashtype/ime');

  final STTSettingsService _sttSettingsService = STTSettingsService();
  final LLMSettingsService _llmSettingsService = LLMSettingsService();
  bool _llmEnabled = true;
  bool _showPeriodButton = true;
  String _llmSubtitle = 'Loading...';
  String _sttSubtitle = 'Loading...';
  String _languageSubtitle = 'Loading...';
  bool _llmNeedsConfig = false;
  bool _sttNeedsConfig = false;

  bool _floatingMicEnabled = false;
  bool _floatingMicAutoFold = false;
  bool _accessibilityEnabled = false;
  bool _imeEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    final appSettings = AppSettingsService();
    final llmSummary = await _llmSettingsService.getSummary();
    final sttSummary = await _sttSettingsService.getSummary();
    final languageSub = await appSettings.getSelectedLanguageNames();
    final showPeriod = await appSettings.getShowPeriodButton();
    final floatingEnabled = await appSettings.getFloatingMicEnabled();
    final floatingAutoFold = await appSettings.getFloatingMicAutoFold();

    bool accessibilityEnabled = false;
    try {
      accessibilityEnabled = await _platform.invokeMethod<bool>('isAccessibilityServiceEnabled') ?? false;
    } catch (_) {}

    bool imeEnabled = false;
    try {
      imeEnabled = await _platform.invokeMethod<bool>('isIMEEnabled') ?? false;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _llmEnabled = llmSummary.enabled;
        _llmSubtitle = llmSummary.subtitle;
        _llmNeedsConfig = llmSummary.needsConfiguration;
        _sttSubtitle = sttSummary.subtitle;
        _sttNeedsConfig = sttSummary.needsConfiguration;
        _languageSubtitle = languageSub;
        _showPeriodButton = showPeriod;
        _floatingMicEnabled = floatingEnabled;
        _floatingMicAutoFold = floatingAutoFold;
        _accessibilityEnabled = accessibilityEnabled;
        _imeEnabled = imeEnabled;
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
              _buildSectionHeader(context, 'Keyboard'),
              _buildSettingTile(
                context,
                icon: Icons.keyboard_rounded,
                title: 'Enable Keyboard',
                subtitle: _imeEnabled
                    ? 'Hashtype keyboard is active'
                    : 'Tap to enable in system settings',
                subtitleColor: _imeEnabled ? null : Colors.orange,
                onTap: () async {
                  try {
                    await _platform.invokeMethod('openIMESettings');
                  } catch (_) {}
                },
                trailing: Switch(
                  value: _imeEnabled,
                  onChanged: (v) async {
                    try {
                      await _platform.invokeMethod('openIMESettings');
                    } catch (_) {}
                  },
                ),
              ),
              _buildSettingTile(
                context,
                icon: Icons.keyboard_outlined,
                title: 'Show Period Button',
                subtitle: 'Add a period (.) button to the keyboard',
                trailing: Switch(
                  value: _showPeriodButton,
                  onChanged: (v) async {
                    await AppSettingsService().setShowPeriodButton(v);
                    setState(() {
                      _showPeriodButton = v;
                    });
                  },
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Floating Voice Input'),
              _buildSettingTile(
                context,
                icon: Icons.bubble_chart_outlined,
                title: 'Enable Floating Mic',
                subtitle: 'Show a draggable mic button over other apps',
                trailing: Switch(
                  value: _floatingMicEnabled,
                  onChanged: (v) async {
                    if (v) {
                      final overlayGranted = await _platform.invokeMethod<bool>('isOverlayPermissionGranted') ?? false;
                      if (!overlayGranted) {
                        await _platform.invokeMethod('requestOverlayPermission');
                        return;
                      }
                    }
                    await AppSettingsService().setFloatingMicEnabled(v);
                    setState(() {
                      _floatingMicEnabled = v;
                    });
                  },
                ),
              ),
              if (_floatingMicEnabled) ...[
                _buildSettingTile(
                  context,
                  icon: Icons.border_outer_rounded,
                  title: 'Auto Fold on Border',
                  subtitle: 'Hide mic button to screen edge when dragged to border',
                  trailing: Switch(
                    value: _floatingMicAutoFold,
                    onChanged: (v) async {
                      await AppSettingsService().setFloatingMicAutoFold(v);
                      setState(() {
                        _floatingMicAutoFold = v;
                      });
                    },
                  ),
                ),
                _buildSettingTile(
                  context,
                  icon: Icons.accessibility_new_rounded,
                  title: 'Auto-Paste Helper',
                  subtitle: _accessibilityEnabled
                      ? 'Accessibility Service is active'
                      : 'Tap to enable automatic pasting',
                  subtitleColor: _accessibilityEnabled ? null : Colors.orange,
                  onTap: () async {
                    await _platform.invokeMethod('openAccessibilitySettings');
                  },
                  trailing: Icon(
                    _accessibilityEnabled ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                    color: _accessibilityEnabled ? Colors.green : Colors.orange,
                  ),
                ),
                _buildSettingTile(
                  context,
                  icon: Icons.tune_rounded,
                  title: 'Customize Floating Mic',
                  subtitle: 'Change colors, sizes, and icons',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FloatingMicCustomizePage(),
                      ),
                    );
                    _loadSettings();
                  },
                ),
              ],
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
                subtitle: 'Version 2.0.0',
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
