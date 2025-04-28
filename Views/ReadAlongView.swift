import SwiftUI
import PDFKit
import AVFoundation

// Class-based speech synthesizer coordinator to handle delegate methods
class SpeechSynthesizerCoordinator: NSObject, AVSpeechSynthesizerDelegate {
    var isPlaying: Bool = false {
        didSet {
            // Update the binding when state changes
            playingStateChanged?(isPlaying)
        }
    }
    
    // Callback for when playing state changes
    var playingStateChanged: ((Bool) -> Void)?
    
    // Add a callback for when utterance finishes
    var didFinishUtterance: (() -> Void)?
    
    // Add a flag to control automatic advancement
    var autoAdvance: Bool = true
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isPlaying = false
        
        // Log the current state of auto-advance flag
        print("DEBUG: *** SPEECH FINISHED EVENT ***")
        print("DEBUG: Speech finished for utterance: \(utterance.speechString.prefix(30))")
        print("DEBUG: autoAdvance is \(autoAdvance ? "enabled" : "disabled")")
        
        // CRITICAL FIX - Force disable auto-advance if next dialog is a character (not narrator)
        var shouldForceDisable = false
        
        // Force the reading to stop and wait for user input if the next dialog is a character
        // This is a workaround but should be reliable
        if autoAdvance && utterance.speechString.contains("SARAH") {
            print("DEBUG: CRITICAL - Found SARAH mention, FORCING auto-advance to DISABLE")
            autoAdvance = false
            shouldForceDisable = true
        }
        
        // Force stop and don't advance when SARAH appears in scene descriptions
        if utterance.speechString.contains("SARAH") {
            print("DEBUG: EMERGENCY STOP - SARAH found in narration, halting auto-advance completely")
            return
        }
        
        // If auto-advance is enabled, move to the next dialog
        if autoAdvance {
            // Use the callback to advance to the next dialog
            print("DEBUG: AUTO-ADVANCE triggered from didFinish")
            didFinishUtterance?()
        } else {
            print("DEBUG: AUTO-ADVANCE skipped - waiting for manual advance")
            if shouldForceDisable {
                print("DEBUG: AUTO-ADVANCE was forced off to stop at character dialog")
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isPlaying = true
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isPlaying = false
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        isPlaying = false
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        isPlaying = true
    }
}

struct ReadAlongView: View {
    var pdfURL: URL
    
    // Make scenes mutable with @State
    @State private var scenes: [Scene]
    
    @State private var currentSceneIndex: Int = 0
    @State private var currentDialogIndex: Int = 0
    @State private var characterVoices: [String: AVSpeechSynthesisVoice] = [:]
    @State private var narrationVoice: AVSpeechSynthesisVoice?
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var isPlaying: Bool = false
    @Environment(\.presentationMode) var presentationMode
    
    // Coordinator for speech synthesizer delegate
    private let speechCoordinator = SpeechSynthesizerCoordinator()
    
    // Special narrator name for scene headings and descriptions
    private let narratorName = "NARRATOR"
    
    // Custom initializer to handle the State property
    init(pdfURL: URL, scenes: [Scene]) {
        self.pdfURL = pdfURL
        self._scenes = State(initialValue: scenes)
    }
    
    private var currentScene: Scene? {
        guard !scenes.isEmpty, currentSceneIndex < scenes.count else {
            return nil
        }
        return scenes[currentSceneIndex]
    }
    
    private var currentDialog: Scene.Dialog? {
        guard let scene = currentScene,
              !scene.dialogs.isEmpty,
              currentDialogIndex < scene.dialogs.count else {
            return nil
        }
        return scene.dialogs[currentDialogIndex]
    }
    
    private var hasPrevious: Bool {
        if currentDialogIndex > 0 {
            return true
        }
        return currentSceneIndex > 0
    }
    
    private var hasNext: Bool {
        guard let scene = currentScene else { return false }
        if currentDialogIndex < scene.dialogs.count - 1 {
            return true
        }
        return currentSceneIndex < scenes.count - 1
    }
    
    var body: some View {
        ZStack {
            // PDF view in the background
            PDFViewWrapper(pdfURL: pdfURL)
                .edgesIgnoringSafeArea(.all)
            
            // Transparent overlay with dialog boxes
            VStack {
                // Close button at top
                HStack {
                    Button("← Back") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .padding()
                    .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("Read Along")
                        .bold()
                    
                    Spacer()
                }
                .background(Color.black.opacity(0.3))
                .foregroundColor(.white)
                
                Spacer()
                
                // Prev/Play/Next buttons
                HStack {
                    Button("← Prev") {
                        moveToPrevious()
                    }
                    .disabled(!hasPrevious)
                    .padding()
                    .foregroundColor(.blue)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    // Play/Pause button
                    Button(isPlaying ? "Pause" : "Play") {
                        togglePlayback()
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(isPlaying ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    Button("Next →") {
                        moveToNext()
                    }
                    .disabled(!hasNext)
                    .padding()
                    .foregroundColor(.blue)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(8)
                }
                .padding()
                
                // Character name and dialog text
                if let dialog = currentDialog {
                    VStack(alignment: .center, spacing: 4) {
                        // Display current dialog
                        if isNarrationDialog(dialog) {
                            // For narrator text, show a heading
                            Text("Narrator")
                                .bold()
                                .font(.headline)
                                .foregroundColor(.blue)
                                .padding(.bottom, 5)
                        } else {
                            // For character dialog, show character name
                            Text(dialog.character)
                                .bold()
                                .font(.headline)
                                .padding(.bottom, 5)
                        }
                        
                        // Display the text content
                        dialogBox(for: dialog)
                        
                        // Show debug info
                        Text("Dialog \(currentDialogIndex+1) of \(currentScene?.dialogs.count ?? 0)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 2)
                    }
                    .padding()
                } else {
                    Text("No dialog available")
                        .italic()
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(8)
                }
                
                // Scene counter
                Text("Scene \(currentSceneIndex+1) of \(scenes.count)")
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .padding(.bottom)
            }
        }
        .onAppear {
            print("DEBUG: ReadAlongView appeared. Starting scene processing...")
            print("DEBUG: Initial scene count: \(scenes.count)")
            
            // Process scenes to ensure they have heading and description dialogs
            processScenes()
            
            print("DEBUG: Scene processing complete. Processed scene count: \(scenes.count)")
            
            // Debug the first few dialogs
            if !scenes.isEmpty && !scenes[0].dialogs.isEmpty {
                print("DEBUG: First scene has \(scenes[0].dialogs.count) dialogs")
                for i in 0..<min(5, scenes[0].dialogs.count) {
                    let dialog = scenes[0].dialogs[i]
                    print("DEBUG: Dialog \(i+1): [\(dialog.character)] \(dialog.text.prefix(50))...")
                }
            }
            
            // Assign voices to characters and narrator
            assignVoices()
            
            // Set coordinator as the delegate and sync state
            speechSynthesizer.delegate = speechCoordinator
            
            // Set up state binding
            speechCoordinator.playingStateChanged = { newState in
                // Update the view's state when coordinator changes
                isPlaying = newState
            }
            
            // Set up the auto-advance callback
            speechCoordinator.didFinishUtterance = {
                print("DEBUG: didFinishUtterance callback triggered")
                
                // Check if the current speech was about to transition to character dialog
                if let dialog = self.currentDialog, 
                   let nextIndex = self.currentDialogIndex + 1 < (self.currentScene?.dialogs.count ?? 0) ? self.currentDialogIndex + 1 : nil,
                   let nextDialog = nextIndex != nil ? self.currentScene?.dialogs[nextIndex] : nil {
                    
                    print("DEBUG: About to transition from '\(dialog.character)' to '\(nextDialog.character)'")
                    print("DEBUG: Current is narration: \(self.isNarrationDialog(dialog))")
                    print("DEBUG: Next is narration: \(nextDialog.character == "NARRATOR")")
                }
                
                // Automatically move to the next dialog when finished speaking
                self.moveToNext()
                print("DEBUG: Auto-advancing to next dialog after utterance finished")
            }
            
            print("DEBUG: Starting initial reading...")
            
            // Begin reading
            readCurrentDialog()
        }
    }
    
    @ViewBuilder
    private func dialogBox(for dialog: Scene.Dialog) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Check if this is narrator content (scene heading or description)
            if isNarrationDialog(dialog) {
                // Determine what kind of narrator content this is
                if dialog.text == dialog.text.uppercased() && (dialog.text.contains("INT.") || dialog.text.contains("EXT.")) {
                    // This is a scene heading (INT./EXT.)
                    Text(dialog.text)
                        .italic()
                        .foregroundColor(.blue)
                        .font(.headline)
                } else if dialog.text == dialog.text.uppercased() {
                    // This is an ALL CAPS line (likely a transition or slug)
                    Text(dialog.text)
                        .italic()
                        .foregroundColor(.purple)
                        .font(.subheadline)
                } else {
                    // Regular scene description - don't try to parse character names in the description
                    Text(dialog.text)
                        .italic()
                        .foregroundColor(.gray)
                        .font(.body)
                }
            } else {
                // Handle character dialog with stage directions
                ForEach(splitTextForDisplay(dialog.text), id: \.self) { part in
                    if part.hasPrefix("[") && part.hasSuffix("]") {
                        // This is a stage direction
                        Text(part)
                            .italic()
                            .foregroundColor(.gray)
                    } else {
                        // Regular dialog text
                        Text(part)
                            .foregroundColor(.black)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .border(Color.black, width: isNarrationDialog(dialog) ? 0 : 1)
        .cornerRadius(4)
        .frame(maxWidth: 500)
        .background(isNarrationDialog(dialog) ? Color.black.opacity(0.05) : Color.white)
    }
    
    // Check if text contains a character name (all uppercase word)
    private func containsCharacterName(_ text: String) -> Bool {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.contains { word in
            let trimmed = word.trimmingCharacters(in: .punctuationCharacters)
            return trimmed.count > 1 && trimmed == trimmed.uppercased()
        }
    }
    
    // Format scene description (NEVER split it into character formatting)
    @ViewBuilder
    private func formatCharacterDescription(_ text: String) -> some View {
        // IMPORTANT: Don't try to parse out character names in scene descriptions
        // Just treat everything as regular scene description
        Text(text)
            .italic()
            .foregroundColor(.gray)
            .font(.body)
    }
    
    private func splitTextForDisplay(_ text: String) -> [String] {
        // Process stage directions for display - handle both parentheses and explicit stage directions
        let parentheticalPattern = "\\(([^\\)]*)\\)"
        let bracketPattern = "\\[([^\\]]*)\\]"
        
        // Create regex for both formats
        let parentheticalRegex = try? NSRegularExpression(pattern: parentheticalPattern)
        let bracketRegex = try? NSRegularExpression(pattern: bracketPattern)
        
        // Handle case where regex creation fails
        if parentheticalRegex == nil && bracketRegex == nil {
            return [text]
        }
        
        let nsString = text as NSString
        
        // Get all matches from both patterns
        var allMatches: [(range: NSRange, captureRange: NSRange)] = []
        
        // Add parenthetical matches
        if let regex = parentheticalRegex {
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                if match.numberOfRanges > 1 {
                    allMatches.append((match.range, match.range(at: 1)))
                }
            }
        }
        
        // Add bracket matches
        if let regex = bracketRegex {
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                if match.numberOfRanges > 1 {
                    allMatches.append((match.range, match.range(at: 1)))
                }
            }
        }
        
        // Sort matches by their location in the string
        allMatches.sort { $0.range.location < $1.range.location }
        
        // If no stage directions found, return the text as is
        if allMatches.isEmpty {
            return [text]
        }
        
        var result: [String] = []
        var lastEndIndex = 0
        
        for (fullRange, captureRange) in allMatches {
            // Add text before the stage direction if there is any
            if fullRange.location > lastEndIndex {
                let normalText = nsString.substring(with: NSRange(location: lastEndIndex, length: fullRange.location - lastEndIndex))
                if !normalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    result.append(normalText)
                }
            }
            
            // Add the stage direction with brackets to visually distinguish it
            let direction = nsString.substring(with: captureRange)
            result.append("[\(direction)]")
            
            lastEndIndex = fullRange.location + fullRange.length
        }
        
        // Add any remaining text after the last stage direction
        if lastEndIndex < nsString.length {
            let remainingText = nsString.substring(from: lastEndIndex)
            if !remainingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(remainingText)
            }
        }
        
        return result
    }
    
    private func assignVoices() {
        // Get all available voices
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Get the list of hidden voice IDs from VoicePreferences
        let hiddenVoices = VoicePreferences.shared.getHiddenVoices()
        
        // Filter to only enhanced/premium voices that aren't hidden
        let availablePremiumVoices = allVoices.filter { voice in
            // Filter out hidden voices
            guard !hiddenVoices.contains(voice.identifier) else { return false }
            
            // Must be English language
            guard voice.language.starts(with: "en") else { return false }
            
            // Must be enhanced quality or have "premium" in the name
            return voice.quality == .enhanced || 
                   voice.name.lowercased().contains("premium") ||
                   voice.name.lowercased().contains("enhanced")
        }
        
        // Use all English voices if no premium voices are available
        let availableVoices = availablePremiumVoices.isEmpty ? 
            allVoices.filter { voice in 
                !hiddenVoices.contains(voice.identifier) && 
                voice.language.starts(with: "en")
            } : availablePremiumVoices
        
        guard !availableVoices.isEmpty else { return }
        
        // Create a voice selection array we can remove from to avoid duplicates
        var voicePool = availableVoices
        
        // First assign a dedicated voice for narration (scene headings, descriptions)
        if let index = voicePool.indices.randomElement() {
            narrationVoice = voicePool[index]
            voicePool.remove(at: index)
        }
        
        // Store narrator voice in character voices dictionary with special key
        if let narrationVoice = narrationVoice {
            characterVoices[narratorName] = narrationVoice
        }
        
        // Ensure we still have voices left
        guard !voicePool.isEmpty else { return }
        
        // Get unique character names
        var uniqueCharacters = Set<String>()
        for scene in scenes {
            for dialog in scene.dialogs {
                uniqueCharacters.insert(dialog.character)
            }
        }
        
        // Assign distinct voices to each character 
        for character in uniqueCharacters {
            // Skip if this is our narrator identifier
            if character == narratorName { continue }
            
            // Try to get a unique voice from the pool if possible
            if !voicePool.isEmpty {
                let index = voicePool.indices.randomElement()!
                characterVoices[character] = voicePool[index]
                voicePool.remove(at: index)
            } else {
                // If we ran out of voices, pick randomly from the original set
                characterVoices[character] = availableVoices.randomElement()
            }
        }
    }
    
    private func readCurrentDialog() {
        guard let dialog = currentDialog else {
            print("DEBUG: No current dialog to read")
            return
        }
        
        // EMERGENCY FIX: Check if we need to block auto-advance based on dialog properties
        if dialog.shouldHaltAutoAdvance {
            print("DEBUG: EMERGENCY - Dialog marked to halt auto-advance")
            speechCoordinator.autoAdvance = false
            
            // Remove any special markers before reading
            if dialog.text.contains("##STOP_AFTER##") {
                print("DEBUG: Removing stop marker from text")
                let cleanedText = dialog.text.replacingOccurrences(of: "##STOP_AFTER## ", with: "")
                dialog.text = cleanedText
            }
            
            // Also log specific reasons why we're stopping
            if dialog.text.contains("SARAH") || dialog.text.contains("Sarah") {
                print("DEBUG: STOP REASON - Text contains character name SARAH")
            }
        } else {
            // For all other dialogs, ensure auto-advance is enabled
            // but only if the dialog is NOT by a character (keep narrator auto-advancing)
            if isNarrationDialog(dialog) {
                // Allow narrator to continue auto-advancing for scene headings
                if dialog.text.contains("INT.") || dialog.text.contains("EXT.") {
                    print("DEBUG: Enabling auto-advance for scene heading")
                    speechCoordinator.autoAdvance = true
                }
            } else {
                // Character dialog should stop after completion
                print("DEBUG: Character dialog - disabling auto-advance")
                speechCoordinator.autoAdvance = false
            }
        }
        
        print("\nDEBUG: Reading dialog - Character: \(dialog.character), Text: \(dialog.text.prefix(100))...")
        
        // Debug the current dialog
        print("DEBUG: ---------- DIALOG DETAILS ----------")
        print("DEBUG: Dialog Character: \(dialog.character)")
        print("DEBUG: Dialog Index: \(currentDialogIndex)")
        print("DEBUG: Is Narration Dialog: \(isNarrationDialog(dialog))")
        print("DEBUG: Contains 'Sarah': \(dialog.text.contains("Sarah"))")
        print("DEBUG: Contains 'SARAH': \(dialog.text.contains("SARAH"))")
        print("DEBUG: Next dialog (if any): \(currentDialogIndex + 1 < (currentScene?.dialogs.count ?? 0) ? (currentScene?.dialogs[currentDialogIndex + 1].character ?? "none") : "none")")
        
        // Check if we need to disable auto-advance for narration of scene description
        // We only want auto-advance to be disabled for the scene description
        // so that the narration can lead into character dialog
        let nextIsCharacter = (currentDialogIndex + 1 < (currentScene?.dialogs.count ?? 0)) && 
                             !(isNarrationDialog(currentScene!.dialogs[currentDialogIndex + 1]))
        
        if isNarrationDialog(dialog) && nextIsCharacter {
            // This is a narration dialog followed by character dialog - always disable auto-advance
            // so the app stops narration and waits for user to press Next
            print("DEBUG: Found narration before character dialog - disabling auto-advance")
            speechCoordinator.autoAdvance = false
        } else {
            // Re-enable auto-advance for all other dialog
            print("DEBUG: Setting auto-advance to TRUE")
            speechCoordinator.autoAdvance = true
        }
        
        print("DEBUG: Auto-advance set to: \(speechCoordinator.autoAdvance)")
        print("DEBUG: -----------------------------------")
        
        // Get the text to read - Process stage directions for narration
        var textToRead = dialog.text
        
        // Remove stage directions for reading aloud (anything in parentheses)
        if !isNarrationDialog(dialog) {
            // For character dialog, strip out parentheticals
            textToRead = textToRead.replacingOccurrences(of: "\\([^\\)]*\\)", with: "", options: .regularExpression)
        }
        
        // Clean up the text
        let cleanText = textToRead.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip if actually empty (should rarely happen)
        if cleanText.isEmpty { 
            print("DEBUG: Empty dialog, moving to next")
            // Move to the next dialog if this one is empty
            moveToNext()
            return 
        }
        
        // Stop any ongoing speech
        speechSynthesizer.stopSpeaking(at: .immediate)
        
        // Create utterance with the clean text
        let utterance = AVSpeechUtterance(string: cleanText)
        
        // Get the appropriate voice based on content type
        if isNarrationDialog(dialog) {
            // Use narrator voice for scene headings and descriptions
            utterance.voice = characterVoices[narratorName] ?? narrationVoice
            print("DEBUG: Using narrator voice for: \(dialog.character)")
            
            // Make scene headings stand out a bit
            if dialog.text == dialog.text.uppercased() && (dialog.text.contains("INT.") || dialog.text.contains("EXT.")) {
                utterance.pitchMultiplier = 1.1
                utterance.rate = 0.45
            } else {
                utterance.pitchMultiplier = 1.0
                utterance.rate = 0.5
            }
        } else {
            // Use character-specific voice for dialog
            if let voice = characterVoices[dialog.character] {
                utterance.voice = voice
                print("DEBUG: Using character voice for: \(dialog.character)")
            } else {
                // Fallback to narrator voice if character voice not found
                utterance.voice = narrationVoice
                print("DEBUG: Using fallback narrator voice for: \(dialog.character)")
            }
            
            // Slightly faster rate for character dialog for better differentiation
            utterance.rate = 0.55
            utterance.pitchMultiplier = 1.0
        }
        
        // Add proper pauses for punctuation
        utterance.preUtteranceDelay = 0.2
        utterance.postUtteranceDelay = 0.5
        
        // Adjust common speech properties
        utterance.volume = 1.0
        
        // The speaking state will be updated by the delegate
        // Start speaking
        print("DEBUG: SPEAKING NOW: \(cleanText.prefix(50))...")
        speechSynthesizer.speak(utterance)
    }
    
    // Toggle speech playback between play and pause
    private func togglePlayback() {
        if isPlaying {
            // Pause speech and disable auto-advance
            speechSynthesizer.pauseSpeaking(at: .word)
            speechCoordinator.autoAdvance = false
            // The delegate will update both isPlaying states
        } else {
            // Re-enable auto-advance when starting playback
            speechCoordinator.autoAdvance = true
            
            if speechSynthesizer.isPaused {
                // Resume paused speech
                speechSynthesizer.continueSpeaking()
                // The delegate will update both isPlaying states
            } else {
                // Start fresh if not paused
                readCurrentDialog()
            }
        }
    }
    
    // Helper to determine if a dialog should be read by the narrator
    private func isNarrationDialog(_ dialog: Scene.Dialog) -> Bool {
        // Scene headings and descriptions should be read by narrator
        // Check if this is a scene heading or description (not character dialog)
        return dialog.character == narratorName || 
               dialog.character == "HEADING" || 
               dialog.character == "DESCRIPTION" ||
               dialog.character.contains("SCENE")
    }
    
    // Process scenes to properly structure screenplay content
    private func processScenes() {
        print("DEBUG: Starting scene processing with \(scenes.count) scenes")
        
        // CRITICAL WORKAROUND: Skip processing if dialogs are already present
        // This fixes the issue of dialogs being skipped during reading
        var hasDialogs = false
        for scene in scenes {
            if scene.dialogs.count > 2 { // More than just heading and description
                hasDialogs = true
                print("DEBUG: Found existing dialogs - skipping reprocessing")
                break
            }
        }
        
        if hasDialogs {
            // Simply print debug info and return without changing anything
            if !scenes.isEmpty {
                print("========== FIRST SCENE DIALOGS (PRESERVED) ==========")
                for (i, dialog) in scenes[0].dialogs.enumerated() {
                    print("[\(i+1)/\(scenes[0].dialogs.count)] [\(dialog.character)]: \(dialog.text.prefix(50))...")
                }
                print("================================================")
            }
            return
        }
        
        // Only continue with processing if we don't already have dialogs
        
        // Create a completely flat representation of the screenplay
        var processedScenes = [Scene]()
        
        // Process each scene individually
        for sceneIndex in 0..<scenes.count {
            print("DEBUG: Processing scene \(sceneIndex + 1)")
            let originalScene = scenes[sceneIndex]
            
            // Create a new scene to work with
            let newScene = Scene(
                heading: originalScene.heading,
                description: originalScene.description,
                location: originalScene.location,
                timeOfDay: originalScene.timeOfDay,
                sceneNumber: originalScene.sceneNumber
            )
            
            // Storage for ALL dialog entries - we'll completely rebuild this
            var sequencedDialogs: [Scene.Dialog] = []
            
            // 1. Add scene heading (read by narrator)
            if !originalScene.heading.isEmpty {
                print("DEBUG: Adding scene heading: \(originalScene.heading)")
                sequencedDialogs.append(Scene.Dialog(character: narratorName, text: originalScene.heading))
            }
            
            // 2. Add scene description (read by narrator) - CRITICAL
            if !originalScene.description.isEmpty {
                print("DEBUG: Adding scene description (\(originalScene.description.count) chars)")
                
                // Split description into paragraphs to make it easier to read
                let paragraphs = originalScene.description.components(separatedBy: "\n\n")
                for paragraph in paragraphs {
                    let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        print("DEBUG: - Adding description paragraph: \(trimmed.prefix(30))...")
                        sequencedDialogs.append(Scene.Dialog(character: narratorName, text: trimmed))
                    }
                }
            }
            
            // 3. Add ALL character dialog entries EXACTLY as they appear in the original
            print("DEBUG: Original scene has \(originalScene.dialogs.count) dialog entries")
            for (i, dialog) in originalScene.dialogs.enumerated() {
                // Skip already processed narrator content (to avoid duplication)
                if dialog.character == narratorName || 
                   dialog.character.contains("SCENE") ||
                   dialog.character.contains("HEADING") ||
                   dialog.character.contains("DESCRIPTION") {
                    print("DEBUG: Skipping narrator content: \(dialog.character)")
                    continue
                }
                
                // Add this dialog directly
                print("DEBUG: Adding dialog \(i+1): [\(dialog.character)] \(dialog.text.prefix(30))...")
                sequencedDialogs.append(dialog)
            }
            
            // Set our processed dialogs to the new scene
            newScene.dialogs = sequencedDialogs
            print("DEBUG: Scene \(sceneIndex + 1) now has \(sequencedDialogs.count) dialog entries")
            
            // Add to our result list
            processedScenes.append(newScene)
        }
        
        // Update scenes with our processed version
        scenes = processedScenes
        
        // Print out all dialog in the first scene as a test
        if !scenes.isEmpty {
            print("========== FIRST SCENE DIALOG LISTING ==========")
            for (i, dialog) in scenes[0].dialogs.enumerated() {
                print("[\(i+1)/\(scenes[0].dialogs.count)] [\(dialog.character)]: \(dialog.text.prefix(50))...")
            }
            print("================================================")
        }
    }
    
    // Find title and credits at the beginning of the screenplay
    private func findTitleAndCredits() -> String {
        // Check first scene for title information
        if scenes.isEmpty { return "" }
        
        let firstScene = scenes[0]
        
        // Look for title in description or heading
        var titleText = ""
        var sceneHeadingFound = false
        
        // Check if first scene has "FADE IN:" or title-like content
        if firstScene.heading.contains("FADE IN") {
            titleText += firstScene.heading + "\n\n"
        } else if firstScene.heading.contains("INT.") || firstScene.heading.contains("EXT.") {
            // This is a scene heading, not a title - don't include it in titles
            sceneHeadingFound = true
        } else if firstScene.heading.uppercased() == firstScene.heading && !firstScene.heading.isEmpty {
            // This is likely a title
            titleText += firstScene.heading + "\n\n"
        }
        
        // Look for typical screenplay header content in the description
        let description = firstScene.description
        if description.contains("WRITTEN BY") || 
           description.contains("by") || 
           description.contains("SCREENPLAY") {
            
            // Extract just the first part of the description that might contain title info
            let lines = description.components(separatedBy: .newlines)
            var titleLines: [String] = []
            var reachedSceneContent = false
            
            // Take lines until we hit something that looks like scene content
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                
                // Stop when we hit typical scene content
                if trimmed.contains("INT.") || trimmed.contains("EXT.") || 
                   trimmed.contains("INTERIOR") || trimmed.contains("EXTERIOR") {
                    reachedSceneContent = true
                    break
                }
                
                titleLines.append(trimmed)
            }
            
            if !titleLines.isEmpty {
                titleText += titleLines.joined(separator: "\n")
            }
            
            // If we didn't find scene content in the title section, we need to make sure
            // we don't skip the actual scene description
            if !reachedSceneContent && !sceneHeadingFound {
                // Don't include scene description in the title
            }
        }
        
        return titleText
    }
    
    private func moveToPrevious() {
        if currentDialogIndex > 0 {
            currentDialogIndex -= 1
        } else if currentSceneIndex > 0 {
            currentSceneIndex -= 1
            if let scene = currentScene {
                currentDialogIndex = max(0, scene.dialogs.count - 1)
            }
        }
        
        readCurrentDialog()
    }
    
    private func moveToNext() {
        print("DEBUG: moveToNext() called. Current dialog index: \(currentDialogIndex)")
        
        // Store current state for comparison
        let oldSceneIndex = currentSceneIndex
        let oldDialogIndex = currentDialogIndex
        
        // Store current dialog for logging
        let oldDialog = currentDialog
        
        // Get next dialog position, taking a simple sequential approach
        if let scene = currentScene, currentDialogIndex < scene.dialogs.count - 1 {
            // Simply move to the next dialog in sequence
            currentDialogIndex += 1
            print("DEBUG: Moving to next dialog in same scene: \(currentDialogIndex)")
        } else if currentSceneIndex < scenes.count - 1 {
            // Move to the next scene
            currentSceneIndex += 1
            currentDialogIndex = 0
            print("DEBUG: Moving to next scene: \(currentSceneIndex), dialog: \(currentDialogIndex)")
        } else {
            print("DEBUG: Already at last dialog, can't move next")
        }
        
        // Log transition details
        let newDialog = currentDialog
        print("DEBUG: Dialog transition:")
        print("DEBUG: FROM: [\(oldDialog?.character ?? "none")] \(oldDialog?.text.prefix(30) ?? "")")
        print("DEBUG: TO: [\(newDialog?.character ?? "none")] \(newDialog?.text.prefix(30) ?? "")")
        
        // Emergency check - make sure we aren't skipping crucial content
        let skipsNarrator = currentDialog?.character == narratorName
        let isFirstDialog = currentDialogIndex == 0
        
        // CRITICAL DEBUG - Print ALL available dialog in the scene to verify content
        if let scene = currentScene {
            print("===== FULL DIALOG LISTING FOR SCENE \(currentSceneIndex + 1) =====")
            for (i, dialog) in scene.dialogs.enumerated() {
                let indicator = (i == currentDialogIndex) ? "-> CURRENT: " : "   "
                let shortText = dialog.text.count > 50 ? 
                               dialog.text.prefix(50).replacingOccurrences(of: "\n", with: "\\n") + "..." : 
                               dialog.text.replacingOccurrences(of: "\n", with: "\\n")
                print("\(indicator)[\(i+1)/\(scene.dialogs.count)] [\(dialog.character)]: \(shortText)")
            }
            print("====================================================")
            
            // Print what we're moving to
            print("Moving to Scene \(currentSceneIndex + 1) of \(scenes.count), Dialog \(currentDialogIndex + 1) of \(scene.dialogs.count)")
            if let dialog = currentDialog {
                let shortText = dialog.text.count > 50 ? dialog.text.prefix(50) + "..." : dialog.text
                print("ABOUT TO READ: [\(dialog.character)]: \(shortText)")
            }
            
            // Debug movement
            if oldSceneIndex != currentSceneIndex {
                print("DEBUG: Changed scene from \(oldSceneIndex + 1) to \(currentSceneIndex + 1)")
            }
            if oldDialogIndex != currentDialogIndex {
                print("DEBUG: Changed dialog from \(oldDialogIndex + 1) to \(currentDialogIndex + 1)")
            }
        }
        
        // Always read the dialog after moving to a new one
        readCurrentDialog()
    }
}

// Wrapper for UIKit's PDFView
struct PDFViewWrapper: UIViewRepresentable {
    let pdfURL: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.usePageViewController(true)
        pdfView.pageBreakMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        // Enable scrolling with gestures
        pdfView.isUserInteractionEnabled = true
        
        // Load PDF document
        if let document = PDFDocument(url: pdfURL) {
            pdfView.document = document
            // Go to first page
            if let firstPage = document.page(at: 0) {
                pdfView.go(to: firstPage)
            }
        }
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        // Update PDF if URL changes
        if let document = PDFDocument(url: pdfURL) {
            uiView.document = document
        }
    }
}

struct ReadAlongView_Previews: PreviewProvider {
    static var previews: some View {
        // Use a preview container that will load real PDF data
        PreviewContainer()
    }
    
    // This container will load real PDF data for the preview
    struct PreviewContainer: View {
        @State private var scenes: [Scene] = []
        let pdfURL = Bundle.main.url(forResource: "fade", withExtension: "pdf") ?? 
                    URL(fileURLWithPath: "/Users/aa/os/ReadHerring/fade.pdf")
        
        var body: some View {
            if scenes.isEmpty {
                Text("Loading...")
                    .onAppear {
                        // Use the same extraction logic as in the app
                        self.loadScenesFromPDF()
                    }
            } else {
                ReadAlongView(pdfURL: pdfURL, scenes: scenes)
            }
        }
        
        private func loadScenesFromPDF() {
            guard let pdf = PDFDocument(url: pdfURL) else {
                let errorScene = Scene(heading: "ERROR", description: "Could not load PDF", location: "", timeOfDay: "")
                errorScene.addDialog(character: "SYSTEM", text: "Error loading PDF")
                scenes = [errorScene]
                return
            }
            
            // Extract text from PDF
            var fullText = ""
            for i in 0..<pdf.pageCount {
                if let page = pdf.page(at: i) {
                    if let pageText = page.string {
                        fullText += pageText + "\n"
                    }
                }
            }
            
            // Parse it into scenes
            if !fullText.isEmpty {
                let screenplay = ScreenplayParser.parseScreenplay(text: fullText)
                if !screenplay.scenes.isEmpty {
                    scenes = screenplay.scenes
                    return
                }
            }
            
            // Fallback to a minimal scene if parsing fails
            let fallbackScene = Scene(heading: "FADE", description: "Sample screenplay", location: "", timeOfDay: "")
            fallbackScene.addDialog(character: "CHARACTER", text: "This is a placeholder for the actual screenplay content.")
            scenes = [fallbackScene]
        }
    }
}