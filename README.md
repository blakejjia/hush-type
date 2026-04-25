<p align="center">
  <img src="assets/icon/play_store_512.png" width="128" height="128" alt="Hashtype Icon">
</p>

# Hashtype 🎙️

**Hashtype** is an open-source Android Voice Typing Keyboard (IME) designed for users who want complete control over their speech-to-text (STT) pipeline.

Unlike standard keyboards that lock you into a single provider, Hashtype allows you to bring your own API endpoints and layer Large Language Models (LLMs) on top of your transcripts for perfect, context-aware results.

---

## 🌟 Key Features

- **Open Source:** Completely transparent and free to use. Host your own backends or use your favorite providers.
- **Custom API Endpoints:**
  - **Speech-to-Text:** Support for OpenAI-compatible transcription APIs (like Whisper).
  - **Large Language Models:** Support for OpenAI, Anthropic, and Google Gemini.
- **AI Cleaning Pipeline:** Automatically send your STT transcript to an LLM to fix grammar, punctuation, and context errors before it's even typed.
- **Customizable System Prompts:** Tailor exactly how the AI "cleans" your text. Want it to translate? Summarize? Formalize? Just change the system prompt.
- **Privacy First:** No intermediate servers. The app communicates directly with your specified API endpoints.
- **Material 3 Design:** A modern, clean keyboard interface that supports dynamic colors and looks great on Android.

---

## 📸 Screenshots

|             Keyboard Ready             |                   Settings                   |                       STT Config                       |                             LLM Config                              |                 Final Result                 |
| :------------------------------------: | :------------------------------------------: | :----------------------------------------------------: | :-----------------------------------------------------------------: | :------------------------------------------: |
| ![Ready](assets/listing_pic/ready.jpg) | ![Settings](assets/listing_pic/settings.jpg) | ![STT Settings](assets/listing_pic/stt%20settings.jpg) | ![LLM Settings](assets/listing_pic/language%20model%20settings.jpg) | ![Inserted](assets/listing_pic/inserted.jpg) |

---

## 🛠️ How it Works

1. **Record:** Tap the mic and speak. The keyboard records high-quality audio.
2. **Transcribe:** Audio is sent to your chosen **STT Provider** (e.g., Whisper).
3. **Refine (Optional):** The transcript is sent to your chosen **LLM Provider** (e.g., GPT-4o, Claude 3.5 Sonnet, Gemini 1.5 Pro).
4. **Clean:** The LLM follows your **Custom System Prompt** to polish the text (remove "uhm/ah", fix typos, apply formatting).
5. **Input:** The final, perfect text is committed directly into the text field.

---

## 🚀 Getting Started

### Prerequisites

- Android device running Android 8.0 (API 26) or higher.
- (For Developers) Flutter SDK and Android Studio.

### Setup

1. **Clone the repo:**
   ```bash
   git clone https://github.com/blakejjia/speech-to-text-board-android.git
   ```
2. **Build the app:**
   ```bash
   cd apps/flutter_app
   flutter pub get
   flutter run --release
   ```
3. **Configure Providers:**
   - Open the **Hashtype** app from your launcher.
   - Go to **STT Settings** and enter your endpoint and API key.
   - Go to **LLM Settings**, enable "AI Cleaning", and set your system prompt.
4. **Enable Keyboard:**
   - Go to Android Settings > Languages & Input > On-screen keyboard > Manage keyboards.
   - Turn on **Hashtype**.
   - Switch to Hashtype whenever you need to voice type!

---

## 🏗️ Architecture

- **`apps/flutter_app`**: The main configuration app and the bridge for settings.
- **`apps/flutter_app/android`**: Contains the native Kotlin `InputMethodService` implementation for high-performance voice recording and IME integration.
- **`services/`**: Shared logic for API communication and provider management.

---

## 🤝 Contributing

We welcome contributions! Whether it's improving the UI, or fixing bugs, feel free to open a PR or an issue.

## 📄 License

This project is licensed under the [GPL v3 License](LICENSE).

---

Made with ❤️ for the open-source community.
