import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/setup_service.dart';
import '../../services/app_settings_service.dart';
import '../settings/speech_to_text_settings_page.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.jia_yx.hashtype/ime');
  bool _isFloatingMicEnabled = false;
  bool _isFloatingMicShowing = false;
  bool _isAccessibilityEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFloatingMicState();
    platform.setMethodCallHandler(_handleMethodCall);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    platform.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'floatingMicStateChanged') {
      _loadFloatingMicState();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadFloatingMicState();
      SetupService().checkStatus();
    }
  }

  Future<void> _loadFloatingMicState() async {
    await AppSettingsService().reload();
    final enabled = await AppSettingsService().getFloatingMicEnabled();
    final showing = await AppSettingsService().getFloatingMicShowing();
    bool accessibilityEnabled = false;
    try {
      accessibilityEnabled = await platform.invokeMethod<bool>('isAccessibilityServiceEnabled') ?? false;
    } catch (e) {
      debugPrint('Error checking accessibility service: $e');
    }

    if (mounted) {
      setState(() {
        _isFloatingMicEnabled = enabled;
        _isFloatingMicShowing = showing;
        _isAccessibilityEnabled = accessibilityEnabled;
      });
    }
  }

  Future<void> _restoreFloatingMic() async {
    await AppSettingsService().clearFloatingMicMuted();
    try {
      await platform.invokeMethod('updateFloatingMicSettings');
    } catch (e) {
      debugPrint('Error updating floating mic settings: $e');
    }
    await _loadFloatingMicState();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('hashtype', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: SetupService(),
        builder: (context, _) {
          final setup = SetupService();
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!setup.isComplete) ...[
                  _buildStatusCard(context, setup),
                  const SizedBox(height: 24),
                ],
                if (_isFloatingMicEnabled && _isAccessibilityEnabled && !_isFloatingMicShowing) ...[
                  _buildRestoreFloatingMicCard(context),
                  const SizedBox(height: 24),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(Icons.mic_none_rounded, size: 64, color: colorScheme.primary),
                        const SizedBox(height: 16),
                        const Text(
                          'Try Your Voice Keyboard',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the input field below to activate the hashtype keyboard. Speak naturally to see the results.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Results will appear here...',
                    labelText: 'Transcription Field',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.text_fields),
                    filled: true,
                    fillColor: colorScheme.surface,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Tips: Ensure the keyboard is enabled in settings and you have granted microphone permissions.',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, SetupService setup) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 20),
              const SizedBox(width: 8),
              Text(
                'Setup Incomplete',
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatusItem(
            context,
            'Microphone Permission',
            setup.hasMicPermission,
            onAction: () async {
              await Permission.microphone.request();
              setup.checkStatus();
            },
          ),
          _buildStatusItem(
            context,
            'AI Configuration',
            setup.isSttConfigured,
            onAction: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SpeechToTextSettingsPage()),
              );
              setup.checkStatus();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(
    BuildContext context,
    String label,
    bool isDone, {
    required VoidCallback onAction,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: isDone ? Colors.green : colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isDone ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
              ),
            ),
          ),
          if (!isDone)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Fix', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildRestoreFloatingMicCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_off_outlined, color: colorScheme.secondary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Floating Mic is Hidden',
                  style: TextStyle(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You muted/hid it. Bring it back now?',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: _restoreFloatingMic,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Bring Back', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
