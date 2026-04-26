import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'pages/onboarding/welcome_page.dart';
import 'pages/main/main_screen.dart';
import 'services/theme_manager.dart';

import 'services/setup_service.dart';

final themeManager = ThemeManager();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await FirebaseAppCheck.instance.activate();

  runApp(const HashtypeApp());
}

class HashtypeApp extends StatefulWidget {
  const HashtypeApp({super.key});

  @override
  State<HashtypeApp> createState() => _HashtypeAppState();
}

class _HashtypeAppState extends State<HashtypeApp> with WidgetsBindingObserver {
  bool? _isSetupComplete;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SetupService().addListener(_onSetupChanged);
    _checkSetup();
  }

  void _onSetupChanged() {
    if (mounted) {
      setState(() {
        _isSetupComplete = SetupService().isComplete;
      });
    }
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

  Future<void> _checkSetup() async {
    await SetupService().checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    if (_isSetupComplete == null) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return ListenableBuilder(
      listenable: themeManager,
      builder: (context, _) {
        return MaterialApp(
          title: 'hashtype',
          debugShowCheckedModeBanner: false,
          themeMode: themeManager.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeManager.primaryColor,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.outfitTextTheme(),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade200),
              ),
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeManager.primaryColor,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white10),
              ),
            ),
          ),
          home: _isSetupComplete! ? const MainScreen() : const WelcomePage(),
        );
      }
    );
  }
}
