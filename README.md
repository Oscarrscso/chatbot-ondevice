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

## Clone, build and install

From Terminal on your Mac:

```sh
git clone https://github.com/Oscarrscso/chatbot-ondevice.git
cd chatbot-ondevice
open PocketChat.xcodeproj
```

In Xcode: select the **PocketChat** target → **Signing & Capabilities** → choose your personal **Team** and turn on automatic signing. Change `dev.oscar.pocketchat` to your own unique bundle ID if needed.

Connect/unlock/trust your iPhone, enable Developer Mode if prompted, select the iPhone as the run destination, and press **Cmd-R**. Test on a physical device: Simulator behaviour for Foundation Models can differ.

CLI build (signing configured in Xcode):

```sh
xcodebuild -project PocketChat.xcodeproj -scheme PocketChat -configuration Debug -destination 'generic/platform=iOS' build
```

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
