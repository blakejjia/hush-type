import 'package:flutter/material.dart';
import 'widgets/stt_engine_selection_list.dart';

class SpeechToTextSettingsPage extends StatefulWidget {
  const SpeechToTextSettingsPage({super.key});

  @override
  State<SpeechToTextSettingsPage> createState() => _SpeechToTextSettingsPageState();
}

class _SpeechToTextSettingsPageState extends State<SpeechToTextSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speech-to-Text', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: const STTEngineSelectionList(),
    );
  }
}
