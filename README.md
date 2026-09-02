# MathCapture

macOS menu-bar app that captures a screen region containing a math formula and copies the recognized result (MathML or LaTeX) to your clipboard.

## Requirements

- macOS 14.0+
- **Apfel** (local, default): [apfel](https://github.com/Arthur-Ficial/apfel) — macOS 26+, Apple Silicon, Apple Intelligence enabled
- **Cloud providers**: an API key for the chosen provider

## Supported Providers

| Provider | Type | Models | Auth |
|---|---|---|---|
| **Apfel (Local)** | On-device (default) | `apple-foundationmodel` | None (optional `--token`) |
| **Google Gemini** | Cloud | `gemini-2.0-flash`, `gemini-2.5-pro` | [API Key](https://aistudio.google.com/app/apikey) |
| **OpenAI** | Cloud | `gpt-4o`, `gpt-4o-mini` | [API Key](https://platform.openai.com/api-keys) |
| **Anthropic** | Cloud | `claude-sonnet-4-20250514`, `claude-3-5-haiku-latest` | [API Key](https://console.anthropic.com/) |
| **GitHub AI** | Cloud | `gpt-4o`, `gpt-4o-mini`, `claude-sonnet-4`, `gemini-2.0-flash` | [GitHub Token](https://github.com/marketplace/models) |

## Installation

```bash
git clone <repo>
cd MathCapture
./build.sh              # debug build + .app bundle
# or ./build.sh release for a release build
open MathCapture.app
```

`swift build` works directly too — `build.sh` also creates and signs the `.app` bundle (required on macOS).

### Optional: Install Apfel for on-device recognition

```bash
brew install apfel
```

See [apfel docs](https://github.com/Arthur-Ficial/apfel) for alternative install methods (source, Nix, Mint).

## Usage

1. **Default (local)**: Apfel is selected by default — no setup needed if `apfel` is installed
2. **Cloud providers**: Set your API key and model in **Settings** (menu bar → MathCapture icon → Settings)
3. Press `⌘⌥M` (configurable) or click **Capture Formula** in the menu bar
4. Click and drag to select the formula on screen
5. Press `Esc` to cancel
6. The result is automatically copied to your clipboard

You can switch between **MathML** and **LaTeX** output in Settings or directly from the menu bar.

## Architecture

- **Entrypoint**: SwiftUI `App` with `MenuBarExtra` scene
- **Capture**: Full-screen `NSPanel` with selection overlay → `CGWindowListCreateImage` for region screenshot
- **Recognition**: `InferenceService` (Swift actor) calls the chosen provider's API (cloud) or invokes `apfel -f` (local) and parses the response
- **Settings**: API keys in macOS Keychain, preferences in `UserDefaults`
- **Clipboard**: Result copied to `NSPasteboard` for pasting anywhere

## Dependencies

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) 1.15.0 — global keyboard shortcut support

## License

MIT
