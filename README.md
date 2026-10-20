# PocketChat

A native SwiftUI chatbot powered by Apple's **on-device Foundation Models framework**. Designed for iPhone 17 and other Apple Intelligence-compatible devices. No API keys, paid AI provider, account, analytics, or network connection required.

## Features

- Streaming replies using the Apple Intelligence system language model
- Multiple conversations and locally saved history
- Follow-up questions with bounded conversation context
- Native chat bubbles, copy message, stop generation, new/delete conversation, dark mode
- Clear handling when Apple Intelligence is disabled, downloading, or unsupported

**Important:** Apple’s on-device model is smaller and less capable than cloud-based assistants. It can be inaccurate, and the app does not browse the web. The model may be unavailable until Apple Intelligence finishes downloading.

## Requirements

- macOS with **Xcode 27 or later** and iOS 27 SDK
- iPhone 17 or another Apple Intelligence-compatible iPhone on **iOS 27+**
- Apple Intelligence enabled in Settings with its on-device language model available
- Apple development team selected in Xcode (a personal team works for your own phone)

## Clone, build and install on iPhone

**One-time setup:** Install and open full Xcode. Open `PocketChat.xcodeproj`, select the PocketChat target → **Signing & Capabilities**, choose your Apple development **Team**, and enable automatic signing. Your free Personal Team can sign apps for your own phone. Change `dev.oscar.pocketchat` if that bundle identifier is already in use.

On your iPhone, enable **Developer Mode** (Settings → Privacy & Security), connect it to your Mac over USB, unlock it, and tap **Trust This Computer**. Ensure Apple Intelligence is enabled and downloaded.

**First installation using Mac Terminal (builds, installs and launches the app):**

```bash
git clone https://github.com/Oscarrscso/chatbot-ondevice.git
cd chatbot-ondevice
bash scripts/install-iphone.sh
```

**To pull changes and reinstall later:**

```bash
cd chatbot-ondevice
git pull
bash scripts/install-iphone.sh
```

The script automatically detects a connected iPhone, runs `xcodebuild`, signs with your configured Xcode team, installs with `xcrun devicectl device install app`, and attempts to launch it. You do not need to install `xcodegen`.

If multiple iPhones are connected, supply the device ID:

```bash
xcrun devicectl list devices
bash scripts/install-iphone.sh YOUR_IPHONE_DEVICE_ID
```

If you prefer to supply a team ID explicitly:

```bash
APPLE_TEAM_ID=YOUR_TEAM_ID bash scripts/install-iphone.sh
```

Alternatively, select your iPhone as the run destination in Xcode and press **Cmd-R**. If signing/build fails, inspect the actual Xcode error. The installation script has not been run on macOS in this environment.

To regenerate the Xcode project from the included `project.yml` (optional):

```sh
brew install xcodegen
xcodegen generate
```

## Source structure

- `PocketChat/PocketChatApp.swift`: app entry
- `PocketChat/ChatModels.swift`: chat records
- `PocketChat/ChatStore.swift`: JSON persistence in app sandbox
- `PocketChat/ChatEngine.swift`: Foundation Models streaming and bounded context
- `PocketChat/ChatView.swift`: native chat UI
- `project.yml`: reproducible Xcode project definition

All prompts and messages remain inside the app and the Apple on-device model. The project does not add cloud calls. Long histories are truncated to respect the model's context limit. Deleting the app will typically delete its local chat data; back up before uninstalling.

## Build status

The project was authored without access to macOS/Xcode. Its final iPhone build and runtime behaviour must be verified in Xcode on a compatible iPhone; do not treat a successful GitHub commit as an Xcode build.
