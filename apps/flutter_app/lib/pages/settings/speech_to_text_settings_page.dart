import 'package:flutter/material.dart';
import 'widgets/stt_engine_selection_list.dart';

class SpeechToTextSettingsPage extends StatefulWidget {
  const SpeechToTextSettingsPage({super.key});

  @override
  State<SpeechToTextSettingsPage> createState() => _SpeechToTextSettingsPageState();
}

class _SpeechToTextSettingsPageState extends State<SpeechToTextSettingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speech-to-Text', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Dictation', icon: Icon(Icons.mic)),
            Tab(text: 'Note Recording', icon: Icon(Icons.description)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          STTEngineSelectionList(),
          STTEngineSelectionList(),
        ],
      ),
    );
  }
}
