import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/main/main_screen.dart';
import 'services/theme_manager.dart';

import 'services/setup_service.dart';

final themeManager = ThemeManager();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const HashtypeApp());
}

class HashtypeApp extends StatefulWidget {
  const HashtypeApp({super.key});

  @override
  State<HashtypeApp> createState() => _HashtypeAppState();
}

class _HashtypeAppState extends State<HashtypeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Just trigger checkStatus once at start
    SetupService().checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SetupService().checkStatus();
    }
  }


  @override
  Widget build(BuildContext context) {

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
          home: const MainScreen(),
        );
      }
    );
  }
}
