# Agent Notes — Speech-to-Text Board

This file documents key architectural decisions and gotchas for AI agents working on this codebase.

---

## AI Provider Settings Architecture

### 双端实现（Dart + Kotlin）

本项目的 AI provider 配置逻辑在两个语言端各维护了一份独立实现：

- **Dart 端**：`lib/services/ai_provider_registry.dart` + `lib/services/ai_feature_settings_service.dart`
- **Kotlin 端**：`android/app/src/main/kotlin/com/jiayx/voiceime/ImeSettingsResolver.kt`

两端都从 `FlutterSharedPreferences`（SharedPrefs）读取相同的**原始 settings** JSON，然后各自独立计算运行时配置（endpoint、auth、requestType 等）。

### 为什么这样设计（不建议更改）

- Kotlin 端（IME Service）在 Flutter app 未启动时就可能运行，因此不能依赖 Dart 端先写入计算好的 runtime 缓存
- 原始 settings 的 schema 非常稳定（provider 名、api_key、model 等字符串），跨语言共享风险低
- 两端独立计算使各自的业务逻辑可以独立演化

### ⚠️ 维护注意事项

**如果需要修改 provider 相关逻辑，必须同时更新两端：**

| 变更类型 | Dart 端 | Kotlin 端 |
|---|---|---|
| 新增 provider | `AiProviderRegistry._providers` 中添加 `ProviderSpec` | `ImeSettingsResolver` 中的各 `when` 表达式 |
| 修改 API key 校验规则 | `ProviderSpec.apiKeyValidator` | `ImeSettingsResolver.getApiKeyValidationError()` |
| 修改 endpoint 构建逻辑 | `AiProviderRegistry.build*Endpoint()` 静态方法 | `ImeSettingsResolver.build*Endpoint()` 私有方法 |
| 修改 auth 配置 | `ProviderSpec.authConfig` | `ImeSettingsResolver.getAuthConfig()` |

> **当前决策**：Provider 列表已稳定，不再计划新增。上述双端同步风险为已知且可接受的 trade-off。

---

## Settings Raw Schema

SharedPreferences 中存储的原始 JSON 结构（两端均依赖此 schema，不要随意修改 key 名）：

```json
// flutter.stt_settings / flutter.llm_settings
{
  "provider": "cloud_providers",      // "cloud" | "cloud_providers"
  "cloud_provider": "OpenAI",         // provider 名称
  "providers": {
    "openai": {                        // normalizeProvider(name) 的结果
      "api_key": "sk-...",
      "endpoint": "",                  // Custom provider 时使用
      "model": "whisper-1"
    }
  },
  // LLM only:
  "enabled": true,
  "system_prompt": "..."
}
```
