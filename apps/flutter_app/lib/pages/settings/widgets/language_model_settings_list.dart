import 'package:flutter/material.dart';

class LanguageModelSettingsList extends StatefulWidget {
  final String title;
  const LanguageModelSettingsList({super.key, required this.title});

  @override
  State<LanguageModelSettingsList> createState() => _LanguageModelSettingsListState();
}

class _LanguageModelSettingsListState extends State<LanguageModelSettingsList> {
  String _selectedProvider = 'cloud_providers';
  String _selectedCloudProvider = 'Custom';
  bool _enableCleanup = true;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: SwitchListTile(
            title: Text('Enable ${widget.title.toLowerCase()}'),
            subtitle: const Text('Use AI to format text and follow voice commands'),
            value: _enableCleanup,
            onChanged: (val) => setState(() => _enableCleanup = val),
          ),
        ),
        const SizedBox(height: 24),
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
        enabled: _enableCleanup,
        onTap: () => setState(() => _selectedProvider = id),
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
          onChanged: _enableCleanup ? (v) => setState(() => _selectedProvider = v!) : null,
        ),
      ),
    );
  }

  Widget _buildCloudProviderDetails(BuildContext context) {
    final providers = ['OpenAI', 'Anthropic', 'Google Gemini', 'Groq', 'Custom'];

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
          const Text('Endpoint URL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            enabled: _enableCleanup,
            decoration: InputDecoration(
              hintText: 'https://new-api.jia-yx.com/v1',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Examples: http://localhost:11434/v1 (Ollama), http://localhost:8080/v1 (LocalAI).', 
            style: TextStyle(fontSize: 12, color: Colors.grey)),
          
          const SizedBox(height: 24),
          const Text('API Key (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            enabled: _enableCleanup,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'sk-...sTWD',
              suffixText: 'edit',
              prefixIcon: const Icon(Icons.key, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Available Models', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Row(
                children: [
                  TextButton(onPressed: () {}, child: const Text('Reset')),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: () {}, child: const Text('Refresh')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildModelItem('MiniMax-M2.5', 'minimax'),
          _buildModelItem('Qwen3-30B-A3B', 'custom'),
          _buildModelItem('deepseek-ai/deepseek-v3.2', 'custom'),
          _buildModelItem('deepseek-chat', 'deepseek'),
          _buildModelItem('deepseek-reasoner', 'deepseek'),
          _buildModelItem('gemini-flash-latest', 'vertex-ai'),
        ],
      ),
    );
  }

  Widget _buildModelItem(String name, String owner) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.public, size: 18),
        title: Row(
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text('Owner: $owner', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
