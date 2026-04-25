import 'package:flutter/material.dart';

class MainProviderTile extends StatelessWidget {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final bool isActive;
  final bool enabled;

  const MainProviderTile({
    super.key,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.isActive,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
        enabled: enabled,
        leading: Icon(icon, color: isSelected ? colorScheme.primary : null),
        title: Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (isActive) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
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
          toggleable: false,
        ),
      ),
    );
  }
}

class ProviderConfigView extends StatelessWidget {
  final String selectedCloudProvider;
  final List<String> providers;
  final TextEditingController apiKeyController;
  final TextEditingController endpointController;
  final bool isLoadingModels;
  final bool isApiKeyVerified;
  final bool isBasicValid;
  final bool modelsLoaded;
  final String helpUrl;
  final String apiKeyPlaceholder;
  final String defaultEndpoint;
  final String? errorText;
  final Widget modelsList;
  final bool enabled;
  final ValueChanged<String> onProviderSelected;
  final ValueChanged<String> onApiKeyChanged;
  final ValueChanged<String> onEndpointChanged;

  const ProviderConfigView({
    super.key,
    required this.selectedCloudProvider,
    required this.providers,
    required this.apiKeyController,
    required this.endpointController,
    required this.isLoadingModels,
    required this.isApiKeyVerified,
    required this.isBasicValid,
    required this.modelsLoaded,
    required this.helpUrl,
    required this.apiKeyPlaceholder,
    required this.defaultEndpoint,
    required this.modelsList,
    required this.onProviderSelected,
    required this.onApiKeyChanged,
    required this.onEndpointChanged,
    this.errorText,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: providers.map((p) {
                final isSelected = selectedCloudProvider == p;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p),
                    selected: isSelected,
                    onSelected: enabled ? (v) => onProviderSelected(p) : null,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          if (selectedCloudProvider == 'Custom') ...[
            const Text('Endpoint URL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: endpointController,
              enabled: enabled,
              onChanged: onEndpointChanged,
              decoration: InputDecoration(
                hintText: 'https://yourendpoint.com/v1',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Examples: http://localhost:11434/v1 (Ollama), http://localhost:8080/v1 (LocalAI).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),
          ] else ...[
            Text('Default Endpoint: $defaultEndpoint', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('API Key', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              if (helpUrl.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    // In a real app, use url_launcher
                  },
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('Get Key', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: apiKeyController,
            enabled: enabled,
            obscureText: true,
            onChanged: onApiKeyChanged,
            decoration: InputDecoration(
              hintText: apiKeyPlaceholder,
              prefixIcon: const Icon(Icons.key, size: 18),
              errorText: errorText,
              suffixIcon: isLoadingModels
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : (isApiKeyVerified ? const Icon(Icons.check_circle, color: Colors.green, size: 18) : null),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 24),
          if (modelsLoaded)
            modelsList
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('Enter API key to fetch available models.', style: TextStyle(color: Colors.grey)),
              ),
            ),
        ],
      ),
    );
  }
}
