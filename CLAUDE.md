# ReadHerring Development Notes

## Project Structure
- SwiftUI iOS app for screenplay analysis
- Uses AVSpeechSynthesisVoice for text-to-speech
- PDF processing capabilities

## Data Persistence
- VoicePreferences.swift handles user voice preferences
- Uses UserDefaults for saving hidden voice state
- Files saved to Documents directory during processing

## Common Tasks
1. Build and Run: 
   ```
   xcodebuild -scheme ReadHerring -configuration Debug build
   ```

2. Clean Build:
   ```
   xcodebuild clean
   ```

## Important Notes
- Premium voices are loaded from the system
- Hidden voices are persisted between app launches
- Cast images are currently loaded as placeholders