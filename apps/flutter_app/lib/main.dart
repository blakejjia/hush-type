import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const VoiceIMEApp());
}

class VoiceIMEApp extends StatelessWidget {
  const VoiceIMEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice IME',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WelcomePage(),
    );
  }
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.jiayx.voiceime/ime');
  
  bool _hasMicPermission = false;
  bool _isIMEEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // App lifecycle observer to re-check status when coming back from settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
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

    setState(() {
      _hasMicPermission = status.isGranted;
      _isIMEEnabled = imeEnabled;
    });
  }

  Future<void> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    setState(() {
      _hasMicPermission = status.isGranted;
    });
  }

  Future<void> _openIMESettings() async {
    try {
      await platform.invokeMethod('openIMESettings');
    } on PlatformException catch (e) {
      debugPrint("Failed to open IME settings: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Voice IME'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Setup your Voice Keyboard',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // Step 1: Mic Permission
              ListTile(
                leading: Icon(
                  _hasMicPermission ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: _hasMicPermission ? Colors.green : Colors.grey,
                ),
                title: const Text('1. Grant Microphone Permission'),
                subtitle: const Text('Required to record your voice.'),
                trailing: _hasMicPermission 
                    ? null 
                    : ElevatedButton(
                        onPressed: _requestMicPermission,
                        child: const Text('Grant'),
                      ),
              ),
              const Divider(),
              
              // Step 2: Enable IME
              ListTile(
                leading: Icon(
                  _isIMEEnabled ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: _isIMEEnabled ? Colors.green : Colors.grey,
                ),
                title: const Text('2. Enable Keyboard'),
                subtitle: const Text('Turn on Voice IME in system settings.'),
                trailing: _isIMEEnabled 
                    ? null 
                    : ElevatedButton(
                        onPressed: _openIMESettings,
                        child: const Text('Enable'),
                      ),
              ),
              const Divider(),
              
              const SizedBox(height: 48),
              
              // Proceed button
              ElevatedButton(
                onPressed: (_hasMicPermission && _isIMEEnabled) 
                    ? () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const MainAppPage()),
                        );
                      } 
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Continue to App', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainAppPage extends StatelessWidget {
  const MainAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice IME Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.blue.withOpacity(0.1),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.keyboard, size: 48, color: Colors.blue),
                    SizedBox(height: 16),
                    Text(
                      'Keyboard Test Area',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Tap the field below to try your voice keyboard.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Try typing here...',
                hintText: 'Voice transcription will appear here',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit),
              ),
              maxLines: 3,
            ),
            const Spacer(),
            const Text(
              'More settings coming soon...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
