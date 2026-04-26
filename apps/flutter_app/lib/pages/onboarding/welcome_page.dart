import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/setup_service.dart';
import '../../services/stt_settings_service.dart';
import '../../services/llm_settings_service.dart';
import '../settings/speech_to_text_settings_page.dart';
import '../settings/language_model_settings_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.jia_yx.hashtype/ime');
  
  bool _hasMicPermission = false;
  bool _isIMEEnabled = false;
  bool _sttReady = false;
  String _sttSubtitle = 'Mandatory: Configure Speech-to-Text';
  String _llmSubtitle = 'Optional: Language Model cleanup';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SetupService().addListener(_onSetupChanged);
    _checkStatus();
  }

  void _onSetupChanged() {
    _checkStatus();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SetupService().removeListener(_onSetupChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SetupService().checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    final status = await Permission.microphone.status;
    bool imeEnabled = false;
    try {
      imeEnabled = await platform.invokeMethod('isIMEEnabled');
    } on PlatformException catch (e) {
      debugPrint("Failed to check IME status: '${e.message}'.");
    }

    final sttService = STTSettingsService();
    final sttSummary = await sttService.getSummary();
    
    final llmService = LLMSettingsService();
    final llmSummary = await llmService.getSummary();

    if (mounted) {
      setState(() {
        _hasMicPermission = status.isGranted;
        _isIMEEnabled = imeEnabled;
        _sttReady = !sttSummary.needsConfiguration;
        _sttSubtitle = 'STT: ${sttSummary.subtitle}';
        _llmSubtitle = 'LLM: ${llmSummary.subtitle} (Optional)';
      });
    }
    
    // Also trigger global check if it hasn't been triggered
    if (mounted) {
      // We don't call SetupService().checkStatus() here to avoid infinite loops 
      // if checkStatus() calls notifyListeners() and we are listening.
      // But checkStatus() only notifies if value changed.
    }
  }

  Future<void> _requestMicPermission() async {
    await Permission.microphone.request();
    SetupService().checkStatus();
  }

  Future<void> _openIMESettings() async {
    try {
      await platform.invokeMethod('openIMESettings');
    } on PlatformException catch (e) {
      debugPrint("Failed to open IME settings: '${e.message}'.");
    }
  }

  Future<void> _openAISettings() async {
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'AI Configuration',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.mic_rounded),
              title: const Text('Speech-to-Text'),
              subtitle: Text(_sttSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SpeechToTextSettingsPage()),
                );
                _checkStatus();
              },
            ),
            ListTile(
              leading: const Icon(Icons.psychology_rounded),
              title: const Text('Language Model'),
              subtitle: Text(_llmSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LanguageModelSettingsPage()),
                );
                _checkStatus();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _completeSetup() async {
    await SetupService().checkStatus();
    // main.dart will handle the navigation because it's listening to SetupService
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isReady = _hasMicPermission && _isIMEEnabled && _sttReady;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.4),
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text(
                  'Welcome to\nhashtype',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Transcribe your voice to text instantly with our premium keyboard experience.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                _buildStepCard(
                  context,
                  index: 1,
                  title: 'Microphone Access',
                  subtitle: 'Required to hear and transcribe your voice.',
                  isDone: _hasMicPermission,
                  onTap: _requestMicPermission,
                ),
                const SizedBox(height: 12),
                _buildStepCard(
                  context,
                  index: 2,
                  title: 'Enable Keyboard',
                  subtitle: 'Turn on hashtype in your system settings.',
                  isDone: _isIMEEnabled,
                  onTap: _openIMESettings,
                ),
                const SizedBox(height: 12),
                _buildStepCard(
                  context,
                  index: 3,
                  title: 'AI Configuration',
                  subtitle: 'Configure STT (Mandatory) and LLM (Optional).',
                  isDone: _sttReady,
                  onTap: _openAISettings,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: isReady ? _completeSetup : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Get Started', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard(
    BuildContext context, {
    required int index,
    required String title,
    required String subtitle,
    required bool isDone,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDone ? colorScheme.primaryContainer.withValues(alpha: 0.3) : colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDone ? colorScheme.primary : colorScheme.outlineVariant,
          width: 2,
        ),
        boxShadow: [
          if (isDone)
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDone ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : Text(
                        '$index',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (!isDone)
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
