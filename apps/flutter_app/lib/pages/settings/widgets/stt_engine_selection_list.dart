import 'package:flutter/material.dart';
import '../../../services/stt_settings_service.dart';
import '../../../services/ai_provider_registry.dart';
import 'shared/settings_common_widgets.dart';
import 'shared/provider_settings_controller.dart';

class STTEngineSelectionList extends StatefulWidget {
  const STTEngineSelectionList({super.key});

  @override
  State<STTEngineSelectionList> createState() => _STTEngineSelectionListState();
}

class _STTEngineSelectionListState extends State<STTEngineSelectionList> {
  final STTSettingsService _settingsService = STTSettingsService();
  late final ProviderSettingsController _providerController;

  @override
  void initState() {
    super.initState();
    _providerController = ProviderSettingsController(settingsService: _settingsService)
      ..addListener(_onProviderStateChanged);
    _loadSettings();
  }

  void _onProviderStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _providerController
      ..removeListener(_onProviderStateChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    await _providerController.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        RadioGroup<String>(
          groupValue: _providerController.selectedProvider,
          onChanged: (id) {
            if (id == null) return;
            _providerController.setProviderMode(id);
          },
          child: Column(
            children: [
              MainProviderTile(
                id: 'cloud',
                title: 'Cloud',
                subtitle: 'Reliable accuracy. No setup needed.',
                icon: Icons.cloud_outlined,
                isSelected: _providerController.selectedProvider == 'cloud',
                isActive: _providerController.selectedProvider == 'cloud',
              ),
              MainProviderTile(
                id: 'cloud_providers',
                title: 'Bring Your Own Key',
                subtitle: 'Use your own API key with supported providers.',
                icon: Icons.key_outlined,
                isSelected: _providerController.selectedProvider == 'cloud_providers',
                isActive: _providerController.selectedProvider == 'cloud_providers',
              ),
            ],
          ),
        ),
        if (_providerController.selectedProvider == 'cloud_providers') 
          ProviderConfigView(
            selectedCloudProvider: _providerController.selectedCloudProvider,
            providers: AiProviderRegistry.providersFor(AiProviderFeature.stt),
            apiKeyController: _providerController.apiKeyController,
            endpointController: _providerController.endpointController,
            apiKeyFocusNode: _providerController.apiKeyFocusNode,
            isLoadingModels: _providerController.isLoadingModels,
            isApiKeyVerified: _providerController.isApiKeyVerified,
            isBasicValid: _providerController.isBasicValid,
            modelsLoaded: _providerController.modelsLoaded,
            errorText: _providerController.errorText,
            helpUrl: _providerController.helpUrl,
            apiKeyPlaceholder: _providerController.apiKeyPlaceholder,
            defaultEndpoint: _providerController.defaultEndpoint,
            onProviderSelected: (p) => _providerController.selectCloudProvider(p),
            onApiKeyChanged: (val) => _providerController.updateApiKey(val),
            onEndpointChanged: (val) => _providerController.updateEndpoint(val),
            onClearApiKey: () => _providerController.clearApiKey(),
            modelsList: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Available Models', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ElevatedButton(
                      onPressed: _providerController.isLoadingModels
                          ? null
                          : _providerController.fetchModels,
                      child: const Text('Refresh')
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_providerController.availableModels.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No speech-to-text models found from this endpoint.', style: TextStyle(color: Colors.red))),
                  )
                else
                  RadioGroup<String>(
                    groupValue: _providerController.selectedModel,
                    onChanged: (v) {
                      if (v == null) return;
                      _providerController.selectModel(v);
                    },
                    child: Column(
                      children: _providerController.availableModels
                          .map((m) => _buildModelTile(
                                m.id,
                                'Owner: ${m.ownedBy}',
                                _providerController.selectedModel == m.id,
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildModelTile(String name, String desc, bool active) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _providerController.selectedModel == name;

    return Card(
      key: ValueKey(name),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? colorScheme.primary : colorScheme.outlineVariant),
      ),
      child: ListTile(
        onTap: () {
          _providerController.selectModel(name);
        },
        dense: true,
        leading: Radio<String>(
          value: name,
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
