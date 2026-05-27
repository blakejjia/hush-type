import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/api_model.dart';

enum AiProviderFeature { llm, stt }

class ProviderAuthConfig {
  final String type;
  final String? header;
  final String prefix;
  final String? queryParam;

  const ProviderAuthConfig({
    required this.type,
    this.header,
    this.prefix = '',
    this.queryParam,
  });

  Map<String, String> toJson() {
    final json = <String, String>{'type': type, 'prefix': prefix};
    if (header != null) {
      json['header'] = header!;
    }
    if (queryParam != null) {
      json['query_param'] = queryParam!;
    }
    return json;
  }
}

class ProviderSpec {
  static const String anthropicVersion = '2023-06-01';

  final String name;
  final Set<AiProviderFeature> features;
  final String apiKeyPlaceholder;
  final String helpUrl;
  final String? Function(String key)? apiKeyValidator;
  final Map<AiProviderFeature, String> defaultBaseUrls;
  final Map<AiProviderFeature, String> requestTypes;
  final ProviderAuthConfig authConfig;

  const ProviderSpec({
    required this.name,
    required this.features,
    required this.apiKeyPlaceholder,
    required this.helpUrl,
    required this.apiKeyValidator,
    required this.defaultBaseUrls,
    required this.requestTypes,
    required this.authConfig,
  });

  bool supports(AiProviderFeature feature) => features.contains(feature);

  String defaultBaseUrl(AiProviderFeature feature) => defaultBaseUrls[feature] ?? '';

  String requestType(AiProviderFeature feature) => requestTypes[feature] ?? '';

  String? validateApiKey(String key) {
    final trimmedKey = key.trim();
    if (trimmedKey.isEmpty) {
      return null;
    }
    return apiKeyValidator?.call(trimmedKey);
  }

  Future<http.Response> fetchModels({
    required AiProviderFeature feature,
    required String apiKey,
    required String customEndpoint,
    Duration timeout = const Duration(seconds: 10),
  }) {
    if (!supports(feature)) {
      throw StateError('$name does not support $feature.');
    }

    switch (name) {
      case 'Anthropic':
        final url = Uri.parse(AiProviderRegistry.buildModelsEndpoint(defaultBaseUrl(feature)));
        return http.get(
          url,
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': anthropicVersion,
            'content-type': 'application/json',
          },
        ).timeout(timeout);
      case 'Google Gemini':
        final endpoint = defaultBaseUrl(feature);
        final uri = Uri.parse(endpoint).replace(
          pathSegments: [...Uri.parse(endpoint).pathSegments, 'models'],
          queryParameters: {'key': apiKey},
        );
        return http.get(
          uri,
          headers: const {'content-type': 'application/json'},
        ).timeout(timeout);
      default:
        final baseUrl = resolveModelsBaseUrl(
          feature: feature,
          customEndpoint: customEndpoint,
        );
        if (baseUrl.isEmpty) {
          throw StateError('No endpoint configured for $name.');
        }
        return http.get(
          Uri.parse(AiProviderRegistry.buildModelsEndpoint(baseUrl)),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ).timeout(timeout);
    }
  }

  List<ApiModel> parseModels(AiProviderFeature feature, Map<String, dynamic> data) {
    switch (name) {
      case 'Google Gemini':
        final modelsJson = data['models'];
        if (modelsJson is! List) {
          return const [];
        }
        return modelsJson
            .whereType<Map<String, dynamic>>()
            .map((model) {
              final name = (model['name'] ?? '') as String;
              final id = name.startsWith('models/')
                  ? name.substring('models/'.length)
                  : name;
              final owner = (model['displayName'] ?? 'Google Gemini') as String;
              return ApiModel(id: id, ownedBy: owner);
            })
            .where((model) => model.id.isNotEmpty)
            .toList();
      case 'Anthropic':
        final modelsJson = data['data'];
        if (modelsJson is! List) {
          return const [];
        }
        return modelsJson
            .whereType<Map<String, dynamic>>()
            .map((model) => ApiModel(
                  id: (model['id'] ?? '') as String,
                  ownedBy: (model['display_name'] ?? 'Anthropic') as String,
                ))
            .where((model) => model.id.isNotEmpty)
            .toList();
      default:
        final modelsJson = data['data'];
        if (modelsJson is! List) {
          return const [];
        }
        return modelsJson
            .whereType<Map<String, dynamic>>()
            .map(ApiModel.fromJson)
            .toList();
    }
  }

  String resolveRuntimeEndpoint({
    required AiProviderFeature feature,
    required String model,
    required String customEndpoint,
  }) {
    if (!supports(feature)) {
      return '';
    }

    switch (feature) {
      case AiProviderFeature.llm:
        switch (name) {
          case 'Anthropic':
            return 'https://api.anthropic.com/v1/messages';
          case 'Google Gemini':
            return AiProviderRegistry.buildGeminiGenerateContentEndpoint(model);
          case 'Custom':
            return AiProviderRegistry.buildChatCompletionsEndpoint(customEndpoint);
          default:
            return AiProviderRegistry.buildChatCompletionsEndpoint(defaultBaseUrl(feature));
        }
      case AiProviderFeature.stt:
        if (name == 'Custom') {
          return AiProviderRegistry.buildTranscriptionsEndpoint(customEndpoint);
        }
        return defaultBaseUrl(feature);
    }
  }

  String resolveModelsBaseUrl({
    required AiProviderFeature feature,
    required String customEndpoint,
  }) {
    if (name == 'Custom' && customEndpoint.trim().isNotEmpty) {
      return customEndpoint.trim();
    }
    return defaultBaseUrl(feature);
  }
}

class AiProviderRegistry {
  static final Map<String, ProviderSpec> _providers = {
    'OpenAI': ProviderSpec(
      name: 'OpenAI',
      features: const {AiProviderFeature.llm, AiProviderFeature.stt},
      apiKeyPlaceholder: 'sk-...',
      helpUrl: 'https://platform.openai.com/api-keys',
      apiKeyValidator: (key) {
        if (!RegExp(r'^sk-[A-Za-z0-9_-]{20,}$').hasMatch(key)) {
          return 'OpenAI keys should look like sk-...';
        }
        return null;
      },
      defaultBaseUrls: const {
        AiProviderFeature.llm: 'https://api.openai.com/v1',
        AiProviderFeature.stt: 'https://api.openai.com/v1/audio/transcriptions',
      },
      requestTypes: const {
        AiProviderFeature.llm: 'openai_chat_completions',
        AiProviderFeature.stt: 'openai_audio_transcriptions',
      },
      authConfig: const ProviderAuthConfig(
        type: 'bearer',
        header: 'Authorization',
        prefix: 'Bearer ',
      ),
    ),
    'Anthropic': ProviderSpec(
      name: 'Anthropic',
      features: const {AiProviderFeature.llm},
      apiKeyPlaceholder: 'sk-ant-...',
      helpUrl: 'https://console.anthropic.com/settings/keys',
      apiKeyValidator: (key) {
        if (!RegExp(r'^sk-ant-[A-Za-z0-9_-]{20,}$').hasMatch(key)) {
          return 'Anthropic keys should look like sk-ant-...';
        }
        return null;
      },
      defaultBaseUrls: const {
        AiProviderFeature.llm: 'https://api.anthropic.com/v1',
      },
      requestTypes: const {
        AiProviderFeature.llm: 'anthropic_messages',
      },
      authConfig: const ProviderAuthConfig(
        type: 'header',
        header: 'x-api-key',
      ),
    ),
    'Google Gemini': ProviderSpec(
      name: 'Google Gemini',
      features: const {AiProviderFeature.llm},
      apiKeyPlaceholder: 'AIza...',
      helpUrl: 'https://aistudio.google.com/app/apikey',
      apiKeyValidator: (key) {
        if (!RegExp(r'^AIza[0-9A-Za-z_-]{20,}$').hasMatch(key)) {
          return 'Gemini keys should look like AIza...';
        }
        return null;
      },
      defaultBaseUrls: const {
        AiProviderFeature.llm: 'https://generativelanguage.googleapis.com/v1beta',
      },
      requestTypes: const {
        AiProviderFeature.llm: 'gemini_generate_content',
      },
      authConfig: const ProviderAuthConfig(
        type: 'query',
        queryParam: 'key',
      ),
    ),
    'Groq': ProviderSpec(
      name: 'Groq',
      features: const {AiProviderFeature.llm, AiProviderFeature.stt},
      apiKeyPlaceholder: 'gsk_...',
      helpUrl: 'https://console.groq.com/keys',
      apiKeyValidator: (key) {
        if (!RegExp(r'^gsk_[A-Za-z0-9_-]{20,}$').hasMatch(key)) {
          return 'Groq keys should look like gsk_...';
        }
        return null;
      },
      defaultBaseUrls: const {
        AiProviderFeature.llm: 'https://api.groq.com/openai/v1',
        AiProviderFeature.stt: 'https://api.groq.com/openai/v1/audio/transcriptions',
      },
      requestTypes: const {
        AiProviderFeature.llm: 'openai_chat_completions',
        AiProviderFeature.stt: 'openai_audio_transcriptions',
      },
      authConfig: const ProviderAuthConfig(
        type: 'bearer',
        header: 'Authorization',
        prefix: 'Bearer ',
      ),
    ),
    'Mistral': ProviderSpec(
      name: 'Mistral',
      features: const {AiProviderFeature.stt},
      apiKeyPlaceholder: 'Paste your API key here',
      helpUrl: 'https://console.mistral.ai/api-keys/',
      apiKeyValidator: (key) {
        if (!RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(key)) {
          return 'Mistral keys should be a long token from the console.';
        }
        return null;
      },
      defaultBaseUrls: const {
        AiProviderFeature.stt: 'https://api.mistral.ai/v1/audio/transcriptions',
      },
      requestTypes: const {
        AiProviderFeature.stt: 'openai_audio_transcriptions',
      },
      authConfig: const ProviderAuthConfig(
        type: 'bearer',
        header: 'Authorization',
        prefix: 'Bearer ',
      ),
    ),
    'Custom': ProviderSpec(
      name: 'Custom',
      features: const {AiProviderFeature.llm, AiProviderFeature.stt},
      apiKeyPlaceholder: 'Enter your API key',
      helpUrl: '',
      apiKeyValidator: (key) {
        if (key.length < 6) {
          return 'Enter a longer API key.';
        }
        return null;
      },
      defaultBaseUrls: const {},
      requestTypes: const {
        AiProviderFeature.llm: 'openai_chat_completions',
        AiProviderFeature.stt: 'openai_audio_transcriptions',
      },
      authConfig: const ProviderAuthConfig(
        type: 'bearer',
        header: 'Authorization',
        prefix: 'Bearer ',
      ),
    ),
  };

  static ProviderSpec? tryGet(String provider) => _providers[provider];

  static ProviderSpec get(String provider) =>
      tryGet(provider) ??
      ProviderSpec(
        name: provider,
        features: const {AiProviderFeature.llm, AiProviderFeature.stt},
        apiKeyPlaceholder: 'Enter your API key',
        helpUrl: '',
        apiKeyValidator: (key) {
          if (key.length < 6) {
            return 'Enter a longer API key.';
          }
          return null;
        },
        defaultBaseUrls: const {},
        requestTypes: const {},
        authConfig: const ProviderAuthConfig(
          type: 'bearer',
          header: 'Authorization',
          prefix: 'Bearer ',
        ),
      );

  static List<String> providersFor(AiProviderFeature feature) {
    return _providers.values
        .where((provider) => provider.supports(feature))
        .map((provider) => provider.name)
        .toList(growable: false);
  }

  static Map<String, dynamic>? decodeJson(String body) {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  static String extractErrorMessage(http.Response response) {
    final data = decodeJson(response.body);
    if (data != null) {
      final nestedError = data['error'];
      if (nestedError is Map<String, dynamic>) {
        final message = nestedError['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }

      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    return 'Model lookup failed with status ${response.statusCode}.';
  }

  static String buildTranscriptionsEndpoint(String rawEndpoint) {
    final endpoint = rawEndpoint.trim();
    if (endpoint.isEmpty) {
      return '';
    }

    final normalized =
        endpoint.endsWith('/') ? endpoint.substring(0, endpoint.length - 1) : endpoint;

    if (normalized.endsWith('/audio/transcriptions')) {
      return normalized;
    }

    if (normalized.endsWith('/models')) {
      return '${normalized.substring(0, normalized.length - '/models'.length)}/audio/transcriptions';
    }

    if (normalized.endsWith('/chat/completions')) {
      return '${normalized.substring(0, normalized.length - '/chat/completions'.length)}/audio/transcriptions';
    }

    if (normalized.endsWith('/transcriptions')) {
      return normalized;
    }

    return '$normalized/audio/transcriptions';
  }

  static String buildChatCompletionsEndpoint(String rawEndpoint) {
    final endpoint = rawEndpoint.trim();
    if (endpoint.isEmpty) {
      return '';
    }

    final normalized =
        endpoint.endsWith('/') ? endpoint.substring(0, endpoint.length - 1) : endpoint;

    if (normalized.endsWith('/chat/completions')) {
      return normalized;
    }

    if (normalized.endsWith('/models')) {
      return '${normalized.substring(0, normalized.length - '/models'.length)}/chat/completions';
    }

    if (normalized.endsWith('/audio/transcriptions')) {
      return '${normalized.substring(0, normalized.length - '/audio/transcriptions'.length)}/chat/completions';
    }

    if (normalized.endsWith('/transcriptions')) {
      return '${normalized.substring(0, normalized.length - '/transcriptions'.length)}/chat/completions';
    }

    return '$normalized/chat/completions';
  }

  static String buildGeminiGenerateContentEndpoint(String model) {
    final trimmedModel = model.trim();
    if (trimmedModel.isEmpty) {
      return '';
    }

    final normalizedModel = trimmedModel.startsWith('models/')
        ? trimmedModel.substring('models/'.length)
        : trimmedModel;
    return 'https://generativelanguage.googleapis.com/v1beta/models/$normalizedModel:generateContent';
  }

  static String buildModelsEndpoint(String rawEndpoint) {
    final endpoint = rawEndpoint.trim();
    if (endpoint.isEmpty) {
      return '';
    }

    final normalized =
        endpoint.endsWith('/') ? endpoint.substring(0, endpoint.length - 1) : endpoint;

    if (normalized.endsWith('/models')) {
      return normalized;
    }

    if (normalized.endsWith('/audio/transcriptions')) {
      return '${normalized.substring(0, normalized.length - '/audio/transcriptions'.length)}/models';
    }

    if (normalized.endsWith('/transcriptions')) {
      return '${normalized.substring(0, normalized.length - '/transcriptions'.length)}/models';
    }

    return '$normalized/models';
  }
}
