<p align="center">
  <img src="assets/icon/play_store_512.png" width="128" height="128" alt="Hashtype Icon">
</p>

# Hashtype 🎙️

[English](README.md) | [简体中文](README_zh.md)

**Hashtype** 是一款开源的 Android 语音输入法键盘（IME），专为希望完全掌控语音转文字（STT）流程的用户设计。

与将你锁定在单一服务商的传统键盘不同，Hashtype 允许你使用自己的 API 接口，并在转录结果之上叠加利用大语言模型（LLM）进行润色，从而获得完美且符合语境的输入体验。

---

## 🚀 安装与使用

1. **下载与安装：**
   - 从 [Releases](https://github.com/blakejjia/speech-to-text-board-android/releases) 页面下载最新的 APK 文件并安装到你的 Android 设备上。
2. **配置服务商：**
   - 从桌面启动 **Hashtype** 应用。
   - 进入 **STT 设置**，输入你的接口地址（Endpoint）和 API Key（例如 OpenAI Whisper）。
   - 进入 **LLM 设置**，开启“AI Cleaning”，并设置你的系统提示词（可选但建议开启）。
3. **启用键盘：**
   - 进入 Android 设置 > 语言和输入法 > 屏幕键盘 > 管理键盘。
   - 开启 **Hashtype**。
4. **开始使用：**
   - 在任何应用中，将输入法切换为 **Hashtype**。
   - 点击麦克风图标开始录音，说话，完成后再次点击即可转录并插入文字。

---

## 📸 应用截图

| 键盘界面 | 应用设置 | STT 配置 |
| :---: | :---: | :---: |
| ![Ready](assets/listing_pic/ready.jpg) | ![Settings](assets/listing_pic/settings.jpg) | ![STT Settings](assets/listing_pic/stt%20settings.jpg) |

| LLM 配置 | 输入结果 |
| :---: | :---: |
| ![LLM Settings](assets/listing_pic/language%20model%20settings.jpg) | ![Inserted](assets/listing_pic/inserted.jpg) |

---

## 🌟 核心特性

- **完全开源：** 代码透明，完全免费。你可以使用自己的后端，也可以连接你喜爱的服务商。
- **自定义 API 接口：**
  - **语音转文字 (STT)：** 支持所有兼容 OpenAI 接口标准的转录 API（如 Whisper）。
  - **大语言模型 (LLM)：** 支持 OpenAI、Anthropic (Claude) 和 Google Gemini。
- **AI 文本润色：** 自动将 STT 转录结果发送给 LLM，在文字输入之前修复语法、标点和语境错误。
- **可自定义的系统提示词：** 精确控制 AI 如何“清洗”你的文字。想要翻译？摘要？还是正式化？只需修改系统提示词即可。
- **隐私至上：** 没有中间服务器。应用直接与你指定的 API 接口通信。
- **Material 3 设计：** 现代、简洁的键盘界面，支持动态配色，完美适配 Android 系统。

---

## 🛠️ 工作原理

1. **录音：** 点击麦克风开始说话，键盘会录制高质量音频。
2. **转录：** 音频被发送到你选择的 **STT 服务商**（例如 Whisper）。
3. **润色（可选）：** 转录结果被发送到你选择的 **LLM 服务商**（例如 GPT-4o, Claude 3.5 Sonnet, Gemini 1.5 Pro）。
4. **清洗：** LLM 根据你的 **自定义系统提示词** 对文字进行润色（去除冗余词汇、修复错别字、调整格式）。
5. **输入：** 最终完美的文本被直接输入到当前的文本框中。

---

## 🏗️ 项目架构

- **`apps/flutter_app`**: 主配置应用，负责设置管理和交互桥接。
- **`apps/flutter_app/android`**: 包含原生 Kotlin `InputMethodService`实现，负责高性能音频录制和输入法集成。
- **`services/`**: 负责 API 通信和提供商管理的共享逻辑。

---

## 🤝 参与贡献

我们欢迎任何形式的贡献！无论是改进 UI、修复 Bug 还是优化文档，请随时提交 PR 或 Issue。

## 📄 开源协议

本项目采用 [GPL v3 开源协议](LICENSE).

---

用 ❤️ 为开源社区打造。
