import 'package:flutter/material.dart';

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

class STTEngineSelectionList extends StatefulWidget {
  const STTEngineSelectionList({super.key});

  @override
  State<STTEngineSelectionList> createState() => _STTEngineSelectionListState();
}

class _STTEngineSelectionListState extends State<STTEngineSelectionList> {
  String _selectedProvider = 'cloud_providers';
  String _selectedCloudProvider = 'Groq';
  String _selectedModel = 'Whisper Large v3';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMainProviderTile(
          context,
          id: 'openwhispr',
          title: 'OpenWhispr Cloud',
          subtitle: 'Reliable accuracy. No setup needed.',
          icon: Icons.cloud_outlined,
        ),
        _buildMainProviderTile(
          context,
          id: 'cloud_providers',
          title: 'Cloud Providers',
          subtitle: 'Bring your own API key.',
          icon: Icons.key_outlined,
          isActive: true,
        ),
        if (_selectedProvider == 'cloud_providers') _buildCloudProviderDetails(context),
        
        const SizedBox(height: 16),
        Opacity(
          opacity: 0.5,
          child: _buildMainProviderTile(
            context,
            id: 'local',
            title: 'Local',
            subtitle: 'On-device models. Fully private.',
            icon: Icons.memory_outlined,
            enabled: false,
          ),
        ),
        Opacity(
          opacity: 0.5,
          child: _buildMainProviderTile(
            context,
            id: 'self_hosted',
            title: 'Self-Hosted',
            subtitle: 'Your own server on your network.',
            icon: Icons.dns_outlined,
            enabled: false,
          ),
        ),
      ],
    );
  }

  Widget _buildMainProviderTile(
    BuildContext context, {
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    bool isActive = false,
    bool enabled = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedProvider == id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        onTap: enabled ? () => setState(() => _selectedProvider = id) : null,
        leading: Icon(icon, color: isSelected ? colorScheme.primary : null),
        title: Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (isActive) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Active', style: TextStyle(fontSize: 10, color: colorScheme.primary, fontWeight: FontWeight.bold)),
              ),
            ]
          ],
        ),
        subtitle: Text(subtitle),
        trailing: Radio<String>(
          value: id,
          groupValue: _selectedProvider,
          onChanged: enabled ? (v) => setState(() => _selectedProvider = v!) : null,
        ),
      ),
    );
  }

  Widget _buildCloudProviderDetails(BuildContext context) {
    final providers = ['OpenAI', 'Groq', 'Mistral', 'Custom'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: providers.map((p) {
                final isSelected = _selectedCloudProvider == p;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p),
                    selected: isSelected,
                    onSelected: (v) => setState(() => _selectedCloudProvider = p),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('API Key', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'gsk...',
              suffixText: 'edit',
              prefixIcon: const Icon(Icons.key, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Model', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          _buildModelTile('Whisper Large v3', 'High accuracy speech recognition', true),
          _buildModelTile('Whisper Large v3 Turbo', '216x real-time speed', false),
        ],
      ),
    );
  }

  Widget _buildModelTile(String name, String desc, bool active) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedModel == name;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? colorScheme.primary : colorScheme.outlineVariant),
      ),
      child: ListTile(
        onTap: () => setState(() => _selectedModel = name),
        dense: true,
        leading: Radio<String>(
          value: name,
          groupValue: _selectedModel,
          onChanged: (v) => setState(() => _selectedModel = v!),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc),
        trailing: active ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
          child: const Text('Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ) : null,
      ),
    );
  }
}
