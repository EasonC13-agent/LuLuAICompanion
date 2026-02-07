# LuLu AI Companion 🛡️🤖

An AI-powered companion app for [LuLu Firewall](https://github.com/objective-see/LuLu) that provides intelligent analysis of network connection alerts.

## Features

- **Automatic Detection**: Monitors for LuLu alert windows using macOS Accessibility API
- **Connection Enrichment**: Fetches WHOIS, reverse DNS, and geolocation data
- **AI Analysis**: Uses Claude API to analyze connections and provide recommendations
- **Menu Bar App**: Runs quietly in the background, shows status in menu bar

## How It Works

```
LuLu shows firewall alert
         ↓
Companion detects alert window (Accessibility API)
         ↓
Extracts: Process, IP, Port, DNS
         ↓
Enriches: WHOIS + Geo lookup
         ↓
Claude API analyzes context
         ↓
Shows AI recommendation window
```

## Requirements

- macOS 13.0 or later
- [LuLu Firewall](https://objective-see.com/products/lulu.html) installed
- Claude API key from [Anthropic Console](https://console.anthropic.com/)
- Accessibility permission (prompted on first launch)

## Building

### Option 1: Using XcodeGen (Recommended)

```bash
# Install xcodegen
brew install xcodegen

# Generate Xcode project
cd LuLuAICompanion
xcodegen generate

# Open and build
open LuLuAICompanion.xcodeproj
```

### Option 2: Manual Xcode Project

1. Open Xcode
2. File → New → Project → macOS → App
3. Product Name: `LuLuAICompanion`
4. Bundle ID: `com.lulu-ai.companion`
5. Interface: SwiftUI, Language: Swift
6. Drag all files from `Sources/` into the project
7. Add `Info.plist` and entitlements from `Resources/`
8. Build settings:
   - Set `LSUIElement` to YES (menu bar app)
   - Disable App Sandbox
   - Enable Network Client capability

## Setup

1. Launch the app
2. Grant Accessibility permission when prompted
3. Click the shield icon in menu bar → Settings
4. Enter your Claude API key
5. Enable monitoring

## Usage

Once running, the app will:

1. Detect when LuLu shows a firewall alert
2. Automatically analyze the connection
3. Pop up a window with AI recommendation:
   - ✅ **Allow** - Safe, known service
   - 🚫 **Block** - Suspicious or risky
   - ⚠️ **Caution** - Needs manual review

The AI considers:
- Process reputation and signing status
- Destination IP/domain reputation
- Port and protocol
- WHOIS organization info
- Whether it's a known service (Google, Apple, CDNs, etc.)

## Privacy

- Your API key is stored securely in macOS Keychain
- Connection data is sent to Claude API for analysis
- No data is stored or logged beyond the current session

## License

MIT License

## Credits

- [LuLu](https://github.com/objective-see/LuLu) by Patrick Wardle / Objective-See
- Powered by [Claude](https://anthropic.com) by Anthropic
