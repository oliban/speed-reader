# Blitzreader - Claude Code Instructions

## Project Overview

iOS speed reading app built with SwiftUI and SwiftData. Uses XcodeGen for project management.

## Key Commands

```bash
# Regenerate Xcode project after changing project.yml
xcodegen generate

# Build and upload to TestFlight
./build-testflight.sh

# Build from command line
xcodebuild -project SpeedReader.xcodeproj -scheme SpeedReader -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Architecture

- **SwiftUI** with iOS 17+ features
- **SwiftData** for persistence (Article model)
- **AVSpeechSynthesizer** for TTS
- **SwiftSoup** for HTML parsing

## Important Files

| File | Purpose |
|------|---------|
| `project.yml` | XcodeGen config - regenerate project after changes |
| `ExportOptions.plist` | TestFlight export settings (Team ID: 5XR7USWXMZ) |
| `build-testflight.sh` | Automated TestFlight deployment |
| `SpeedReader/Info.plist` | App configuration (background audio enabled) |

## Code Patterns

### SwiftData Predicates
SwiftData predicates don't support enum comparisons. Filter in Swift instead:
```swift
// Don't do this - crashes
#Predicate<Article> { $0.status == .completed }

// Do this instead
let articles = try modelContext.fetch(FetchDescriptor<Article>())
let filtered = articles.filter { $0.status == .completed }
```

### TTS Speed Changes
When changing TTS speed mid-playback, use an `isRestarting` flag to prevent race conditions with the completion handler.

### Background Audio
Requires both:
1. `UIBackgroundModes: audio` in Info.plist (via project.yml)
2. AVAudioSession configured with `.playback` category (no `.mixWithOthers`)

## CI/CD

**Xcode Cloud** is configured for automatic builds. Pushing to `master` triggers a TestFlight build automatically.

### Manual TestFlight Deployment (alternative)

1. Ensure signed into Xcode (Settings > Accounts)
2. App must exist in App Store Connect
3. Run `./build-testflight.sh`
4. Check App Store Connect for processing status

## Bundle Identifier

`com.fredriksafsten.speedreader`
