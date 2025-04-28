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
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isPlaying = false
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
                        // Only show character name for non-narrator content
                        if !isNarrationDialog(dialog) {
                            Text(dialog.character)
                                .bold()
                                .font(.headline)
                                .padding(.bottom, 5)
                        }
                        
                        dialogBox(for: dialog)
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
            // Process scenes to ensure they have heading and description dialogs
            processScenes()
            
            // Assign voices to characters and narrator
            assignVoices()
            
            // Set coordinator as the delegate and sync state
            speechSynthesizer.delegate = speechCoordinator
            
            // Set up state binding
            speechCoordinator.playingStateChanged = { newState in
                // Update the view's state when coordinator changes
                isPlaying = newState
            }
            
            // Begin reading
            readCurrentDialog()
        }
    }
    
    @ViewBuilder
    private func dialogBox(for dialog: Scene.Dialog) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Check if this is narrator content (scene heading or description)
            if isNarrationDialog(dialog) {
                // For narration, check if it contains character descriptions
                // and format accordingly
                if dialog.text.contains("(") && containsCharacterName(dialog.text) {
                    // This is likely a character description, format it specially
                    formatCharacterDescription(dialog.text)
                } else if dialog.text == dialog.text.uppercased() {
                    // This is a scene heading (ALL CAPS)
                    Text(dialog.text)
                        .italic()
                        .foregroundColor(.blue)
                        .font(.headline)
                } else {
                    // Regular narration
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
    
    // Format text with character descriptions
    @ViewBuilder
    private func formatCharacterDescription(_ text: String) -> some View {
        // Look for pattern: CHARACTER_NAME (description) action
        let pattern = "([A-Z][A-Z\\s]+)\\s*\\(([^\\)]+)\\)\\s*(.*)"
        
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.count)) {
            
            let nsString = text as NSString
            
            // Extract the parts
            let characterName = match.range(at: 1).location != NSNotFound ?
                              nsString.substring(with: match.range(at: 1)) : ""
            
            let description = match.range(at: 2).location != NSNotFound ?
                            nsString.substring(with: match.range(at: 2)) : ""
            
            let action = match.range(at: 3).location != NSNotFound ?
                       nsString.substring(with: match.range(at: 3)) : ""
            
            // Format with different styles for each part
            VStack(alignment: .leading, spacing: 2) {
                if !characterName.isEmpty {
                    Text(characterName)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                }
                
                if !description.isEmpty {
                    Text("(\(description))")
                        .italic()
                        .foregroundColor(.gray)
                }
                
                if !action.isEmpty {
                    Text(action)
                        .foregroundColor(.gray)
                        .italic()
                }
            }
        } else {
            // Fallback for unmatched text
            Text(text)
                .italic()
                .foregroundColor(.gray)
        }
    }
    
    private func splitTextForDisplay(_ text: String) -> [String] {
        // Process stage directions for display
        let pattern = "\\(([^\\)]*)\\)"
        let regex = try? NSRegularExpression(pattern: pattern)
        
        if regex == nil {
            return [text]
        }
        
        let nsString = text as NSString
        let matches = regex!.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        
        if matches.isEmpty {
            return [text]
        }
        
        var result: [String] = []
        var lastEndIndex = 0
        
        for match in matches {
            // Add text before the stage direction if there is any
            if match.range.location > lastEndIndex {
                let normalText = nsString.substring(with: NSRange(location: lastEndIndex, length: match.range.location - lastEndIndex))
                if !normalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    result.append(normalText)
                }
            }
            
            // Add the stage direction with brackets
            let direction = nsString.substring(with: match.range(at: 1))
            result.append("[\(direction)]")
            
            lastEndIndex = match.range.location + match.range.length
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
        guard let dialog = currentDialog else { return }
        
        // Get the text to read
        var textToRead = dialog.text
        
        // Only clean stage directions from character dialog (not from narration)
        if !isNarrationDialog(dialog) {
            // Clean text by removing stage directions (text in parentheses)
            textToRead = dialog.text.replacingOccurrences(
                of: "\\(.*?\\)",
                with: "",
                options: .regularExpression
            )
        }
        
        // Final cleanup
        let cleanText = textToRead.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip if nothing to read
        if cleanText.isEmpty { 
            // Move to the next dialog if this one is empty
            moveToNext()
            return 
        }
        
        // Print debug for current dialog
        print("Reading: [\(dialog.character)] \(cleanText.prefix(50))...")
        
        // Stop any ongoing speech
        speechSynthesizer.stopSpeaking(at: .immediate)
        
        // Create utterance with the clean text
        let utterance = AVSpeechUtterance(string: cleanText)
        
        // Get the appropriate voice based on content type
        if isNarrationDialog(dialog) {
            // Use narrator voice for scene headings and descriptions
            utterance.voice = characterVoices[narratorName] ?? narrationVoice
            
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
            } else {
                // Fallback to narrator voice if character voice not found
                utterance.voice = narrationVoice
            }
            
            // Standard rate for character dialog
            utterance.rate = 0.5
            utterance.pitchMultiplier = 1.0
        }
        
        // Adjust common speech properties
        utterance.volume = 1.0
        
        // The speaking state will be updated by the delegate
        // Start speaking
        speechSynthesizer.speak(utterance)
    }
    
    // Toggle speech playback between play and pause
    private func togglePlayback() {
        if isPlaying {
            // Pause speech
            speechSynthesizer.pauseSpeaking(at: .word)
            // The delegate will update both isPlaying states
        } else {
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
        // Create new array for processed scenes
        var processedScenes = [Scene]()
        
        // Extract titles and credts
        let titleCredits = findTitleAndCredits()
        
        // Process each scene individually
        for sceneIndex in 0..<scenes.count {
            let originalScene = scenes[sceneIndex]
            
            // Create a new scene to work with
            let newScene = Scene(
                heading: originalScene.heading,
                description: originalScene.description,
                location: originalScene.location,
                timeOfDay: originalScene.timeOfDay,
                sceneNumber: originalScene.sceneNumber
            )
            
            // Storage for organized dialogs
            var sequencedDialogs: [Scene.Dialog] = []
            
            // 1. If this is the first scene, add title/credits
            if sceneIndex == 0 && !titleCredits.isEmpty {
                sequencedDialogs.append(Scene.Dialog(character: narratorName, text: titleCredits))
            }
            
            // 2. Add scene heading as a separate narrator dialog (just once)
            // Only add if it's not already in titleCredits to avoid duplication
            if !originalScene.heading.isEmpty && !titleCredits.contains(originalScene.heading) {
                sequencedDialogs.append(Scene.Dialog(character: narratorName, text: originalScene.heading))
            }
            
            // 3. Extract and add scene description (general atmosphere and setting)
            var sceneDescriptionAdded = false
            
            // Regular expression for finding character descriptions
            let characterPattern = "([A-Z][A-Z\\s]+)\\s*\\(([^\\)]+)\\)\\s+(.+)"
            let characterRegex = try? NSRegularExpression(pattern: characterPattern)
            
            // Extract the main scene description without character descriptions
            if !originalScene.description.isEmpty {
                // Split into paragraphs for better reading
                let paragraphs = originalScene.description.components(separatedBy: "\n\n")
                
                // Process ALL paragraphs of the scene description
                for paragraph in paragraphs {
                    let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        // Check if paragraph is a character description
                        if let regex = characterRegex, 
                           regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.count)) != nil {
                            // Character descriptions will be handled before their dialog
                        } else {
                            // This is general scene description - the narrator should read it
                            sequencedDialogs.append(Scene.Dialog(character: narratorName, text: trimmed))
                            sceneDescriptionAdded = true
                        }
                    }
                }
            }
            
            // 4. Build a map of character introductions from scene description
            var characterIntros: [String: String] = [:]  // Character name -> intro text
            
            // Extract character descriptions from the scene description
            let sceneText = originalScene.description
            let sceneLines = sceneText.components(separatedBy: .newlines)
            
            for line in sceneLines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if let regex = characterRegex,
                   let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.count)) {
                    
                    let nsLine = trimmed as NSString
                    let charName = match.range(at: 1).location != NSNotFound ? 
                                 nsLine.substring(with: match.range(at: 1)) : ""
                    
                    // Store the full line as the intro for this character
                    characterIntros[charName] = trimmed
                }
            }
            
            // 5. Track characters who have been introduced
            var introducedCharacters = Set<String>()
            
            // Helper function to check if text contains uppercase words (character names)
            func containsUppercaseWord(_ text: String) -> Bool {
                let words = text.components(separatedBy: .whitespacesAndNewlines)
                return words.contains { word in
                    let trimmed = word.trimmingCharacters(in: .punctuationCharacters)
                    return trimmed.count > 1 && trimmed == trimmed.uppercased() && trimmed != "INT." && trimmed != "EXT."
                }
            }
            
            // Map to track which dialog entries should be skipped (e.g., narrative actions already processed)
            var skipDialogIndices = Set<Int>()
            
            // 6. Process all dialogs and identify narrative sections
            for dialogIndex in 0..<originalScene.dialogs.count {
                // Skip if this dialog was already processed
                if skipDialogIndices.contains(dialogIndex) {
                    continue
                }
                
                let dialog = originalScene.dialogs[dialogIndex]
                
                // Skip any existing narrator content
                if dialog.character == narratorName || 
                   dialog.character.contains("SCENE") ||
                   dialog.character.contains("HEADING") ||
                   dialog.character.contains("DESCRIPTION") {
                    continue
                }
                
                let character = dialog.character
                let dialogText = dialog.text
                
                // Check if we need to introduce this character first
                if !introducedCharacters.contains(character) {
                    // Add the character introduction if we have one
                    if let introText = characterIntros[character] {
                        sequencedDialogs.append(Scene.Dialog(character: narratorName, text: introText))
                    }
                    introducedCharacters.insert(character)
                }
                
                // Now add the character's dialog
                // Check if the dialog contains another character's introduction
                if let regex = characterRegex,
                   let match = regex.firstMatch(in: dialogText, range: NSRange(location: 0, length: dialogText.count)) {
                    
                    // Extract the dialog part vs. character introduction part
                    let nsText = dialogText as NSString
                    
                    let dialogPart = match.range.location > 0 ?
                                   nsText.substring(with: NSRange(location: 0, length: match.range.location))
                                        .trimmingCharacters(in: .whitespacesAndNewlines) : ""
                    
                    let charName = match.range(at: 1).location != NSNotFound ? 
                                 nsText.substring(with: match.range(at: 1)) : ""
                    
                    // Add the character's dialog (if any)
                    if !dialogPart.isEmpty {
                        sequencedDialogs.append(Scene.Dialog(character: character, text: dialogPart))
                    }
                    
                    // Add the character intro for the next character
                    if !charName.isEmpty && !introducedCharacters.contains(charName) {
                        let introText = nsText.substring(with: match.range)
                        sequencedDialogs.append(Scene.Dialog(character: narratorName, text: introText))
                        introducedCharacters.insert(charName)
                    }
                } else {
                    // Regular dialog - add it as is
                    sequencedDialogs.append(dialog)
                }
                
                // Check if next lines contain narrative action
                // Look ahead in the dialog collection to find narrative actions
                if dialogIndex + 1 < originalScene.dialogs.count {
                    var lookAheadIndex = dialogIndex + 1
                    
                    while lookAheadIndex < originalScene.dialogs.count {
                        let nextDialog = originalScene.dialogs[lookAheadIndex]
                        
                        // Stop looking if we hit another character's dialog
                        if nextDialog.character != character && !nextDialog.character.contains("(CONT'D)") &&
                           !nextDialog.character.contains(character) {
                            
                            // Check if this is a narrative action/description, not dialog
                            let nextText = nextDialog.text
                            
                            // Criteria for narrative action:
                            // 1. Contains a character name in CAPS
                            // 2. Is not dialog (no quotes or speech indicators)
                            // 3. Is not a dialog direction (doesn't start with parentheses)
                            let hasCharacterName = containsUppercaseWord(nextText)
                            let isNotDialogDirections = !nextText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("(")
                            let isNotSpeech = !nextText.contains("\"") && !nextText.contains("says") && 
                                             !nextText.contains("says") && !nextText.contains("replies")
                            
                            if hasCharacterName && isNotDialogDirections && isNotSpeech {
                                // This is a narrative action - assign to narrator
                                sequencedDialogs.append(Scene.Dialog(character: narratorName, text: nextText))
                                skipDialogIndices.insert(lookAheadIndex)
                                
                                // Step to next and see if more narrative continues
                                lookAheadIndex += 1
                            } else {
                                // Not a narrative action, stop looking ahead
                                break
                            }
                        } else {
                            // Same character continues or a CONT'D marker, move on
                            break
                        }
                    }
                }
            }
            
            // Set our processed dialogs to the new scene
            newScene.dialogs = sequencedDialogs
            
            // Add to our result list
            processedScenes.append(newScene)
        }
        
        // Update scenes with our processed version
        scenes = processedScenes
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
        if let scene = currentScene, currentDialogIndex < scene.dialogs.count - 1 {
            currentDialogIndex += 1
        } else if currentSceneIndex < scenes.count - 1 {
            currentSceneIndex += 1
            currentDialogIndex = 0
        }
        
        // Print debug info
        if let scene = currentScene {
            print("Moving to Scene \(currentSceneIndex + 1) of \(scenes.count), Dialog \(currentDialogIndex + 1) of \(scene.dialogs.count)")
            if let dialog = currentDialog {
                let shortText = dialog.text.count > 50 ? dialog.text.prefix(50) + "..." : dialog.text
                print("Character: \(dialog.character), Text: \(shortText)")
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