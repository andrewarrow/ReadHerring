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

// Struct to hold voice selection state
struct VoiceSelection: Identifiable {
    let id = UUID()
    let voice: AVSpeechSynthesisVoice
    let name: String
    var isPlaying: Bool = false
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
    
    // States for voice selection modal
    @State private var isVoiceSelectionPresented = false
    @State private var availableVoices: [VoiceSelection] = []
    @State private var currentCharacterForVoiceChange: String = ""
    
    // Coordinator for speech synthesizer delegate
    private let speechCoordinator = SpeechSynthesizerCoordinator()
    
    // Special narrator name for scene headings and descriptions
    private let narratorName = ScreenplayParser.narratorName // Use the shared value
    
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
            PDFViewWrapper(pdfURL: pdfURL, currentDialogText: currentDialog?.text ?? "")
                .edgesIgnoringSafeArea(.all)
            
            // Transparent overlay with controls
            VStack {
                // Header with controls at top
                VStack(spacing: 0) {
                    // Back button and title row
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
                    
                    // Navigation controls at top
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
                    .background(Color.black.opacity(0.2))
                }
                
                Spacer()
                
                // Scene counter and voice controls at bottom
                VStack(spacing: 0) {
                    // Scene counter
                    Text("Scene \(currentSceneIndex+1) of \(scenes.count)")
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.black.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .padding(.bottom, 8)
                    
                    // Character voice info at bottom
                    if let dialog = currentDialog {
                        HStack {
                            // Only show character name for non-narrator content
                            if !isNarrationDialog(dialog) {
                                Text(dialog.character)
                                    .bold()
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                // Display current voice name
                                if let voice = characterVoices[dialog.character] {
                                    Text("(\(voice.name))")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            } else if dialog.character == narratorName {
                                Text("Narrator")
                                    .bold()
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                // Display current voice name
                                if let voice = characterVoices[narratorName] {
                                    Text("(\(voice.name))")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            
                            Spacer()
                            
                            // Button to change voice
                            Button {
                                currentCharacterForVoiceChange = isNarrationDialog(dialog) ? narratorName : dialog.character
                                prepareVoicesForSelection()
                                isVoiceSelectionPresented = true
                            } label: {
                                HStack {
                                    Image(systemName: "speaker.wave.2.circle")
                                    Text("Change Voice")
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.5))
                    }
                }
            }
        }
        .onAppear {
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
        .sheet(isPresented: $isVoiceSelectionPresented) {
            // Voice Selection Sheet
            VStack {
                HStack {
                    Text("Select Voice")
                        .font(.headline)
                        .padding()
                    
                    Spacer()
                    
                    Button {
                        isVoiceSelectionPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
                
                if currentCharacterForVoiceChange == narratorName {
                    Text("Changing voice for Narrator")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Changing voice for \(currentCharacterForVoiceChange)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                List {
                    ForEach(availableVoices) { voiceSelection in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(voiceSelection.name)
                                    .font(.headline)
                                
                                Text(voiceSelection.voice.language)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                if voiceSelection.voice.quality == .enhanced {
                                    Text("Premium Voice")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                            
                            Spacer()
                            
                            Button {
                                // Preview the voice
                                playPreviewVoice(voiceSelection.voice)
                            } label: {
                                Image(systemName: voiceSelection.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 32, height: 32)
                                    .foregroundColor(voiceSelection.isPlaying ? .red : .blue)
                            }
                            
                            Button {
                                // Select this voice for the character
                                changeCharacterVoice(to: voiceSelection.voice)
                                isVoiceSelectionPresented = false
                            } label: {
                                Text("Select")
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(5)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
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
        
        // First assign a dedicated male voice for narration (scene headings, descriptions)
        // Filter for male voices first
        let maleVoices = voicePool.filter { voice in
            let name = voice.name.lowercased()
            return name.contains("male") || 
                   name.contains("man") || 
                   name.contains("guy") || 
                   name.contains("boy") ||
                   (name.contains("tom") && !name.contains("custom"))
        }
        
        if !maleVoices.isEmpty, let index = maleVoices.indices.randomElement() {
            // Found a male voice
            narrationVoice = maleVoices[index]
            // Find and remove from the main pool
            if let poolIndex = voicePool.firstIndex(where: { $0.identifier == maleVoices[index].identifier }) {
                voicePool.remove(at: poolIndex)
            }
        } else if let index = voicePool.indices.randomElement() {
            // Fallback to any voice if no male voices found
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
        print("DEBUG ReadAlongView: Reading current dialog")
        guard let dialog = currentDialog else {
            print("DEBUG ReadAlongView: No current dialog to read")
            return
        }
        
        print("DEBUG ReadAlongView: Current dialog - Scene: \(currentSceneIndex), Dialog: \(currentDialogIndex)")
        print("DEBUG ReadAlongView: Character: \(dialog.character), Text: \(dialog.text.prefix(100))...")
        
        // Clean text by removing stage directions (text in parentheses)
        let cleanText = dialog.text.replacingOccurrences(
            of: "\\(.*?\\)",
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("DEBUG ReadAlongView: Cleaned text length: \(cleanText.count) chars")
        
        // Skip if nothing to read
        if cleanText.isEmpty { 
            print("DEBUG ReadAlongView: Empty text after cleaning, moving to next")
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
            print("DEBUG ReadAlongView: Using narrator voice")
            // Use narrator voice for scene headings and descriptions
            utterance.voice = characterVoices[narratorName] ?? narrationVoice
        } else {
            print("DEBUG ReadAlongView: Using character voice for \(dialog.character)")
            // Use character-specific voice for dialog
            if let voice = characterVoices[dialog.character] {
                utterance.voice = voice
            } else {
                // Fallback to narrator voice if character voice not found
                utterance.voice = narrationVoice
            }
        }
        
        // Adjust speech properties
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
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
        // Simple check if this dialog belongs to the narrator
        return dialog.character == narratorName
    }
    
    private func moveToPrevious() {
        print("DEBUG ReadAlongView: Moving to previous dialog")
        print("DEBUG ReadAlongView: Before move - Scene: \(currentSceneIndex), Dialog: \(currentDialogIndex)")
        
        if currentDialogIndex > 0 {
            print("DEBUG ReadAlongView: Moving to previous dialog in same scene")
            currentDialogIndex -= 1
        } else if currentSceneIndex > 0 {
            print("DEBUG ReadAlongView: Moving to previous scene")
            currentSceneIndex -= 1
            
            if let scene = currentScene {
                currentDialogIndex = max(0, scene.dialogs.count - 1)
                print("DEBUG ReadAlongView: Previous scene has \(scene.dialogs.count) dialogs, setting index to \(currentDialogIndex)")
            }
        } else {
            print("DEBUG ReadAlongView: Already at first dialog of first scene")
        }
        
        print("DEBUG ReadAlongView: After move - Scene: \(currentSceneIndex), Dialog: \(currentDialogIndex)")
        
        // Dump current scene contents for debugging
        if let scene = currentScene {
            print("DEBUG ReadAlongView: Current scene dialogs:")
            for (i, dialog) in scene.dialogs.enumerated() {
                print("DEBUG ReadAlongView: Dialog \(i): \(dialog.character): \(dialog.text.prefix(30))...")
            }
        }
        
        readCurrentDialog()
    }
    
    private func moveToNext() {
        print("DEBUG ReadAlongView: Moving to next dialog")
        print("DEBUG ReadAlongView: Before move - Scene: \(currentSceneIndex), Dialog: \(currentDialogIndex)")
        
        if let scene = currentScene, currentDialogIndex < scene.dialogs.count - 1 {
            print("DEBUG ReadAlongView: Moving to next dialog in same scene")
            currentDialogIndex += 1
        } else if currentSceneIndex < scenes.count - 1 {
            print("DEBUG ReadAlongView: Moving to next scene")
            currentSceneIndex += 1
            currentDialogIndex = 0
            
            if let scene = currentScene {
                print("DEBUG ReadAlongView: Next scene has \(scene.dialogs.count) dialogs")
            }
        } else {
            print("DEBUG ReadAlongView: Already at last dialog of last scene")
        }
        
        print("DEBUG ReadAlongView: After move - Scene: \(currentSceneIndex), Dialog: \(currentDialogIndex)")
        
        // Dump current scene contents for debugging
        if let scene = currentScene {
            print("DEBUG ReadAlongView: Current scene dialogs:")
            for (i, dialog) in scene.dialogs.enumerated() {
                print("DEBUG ReadAlongView: Dialog \(i): \(dialog.character): \(dialog.text.prefix(30))...")
            }
        }
        
        // Always read the dialog after moving to a new one
        readCurrentDialog()
    }
    
    // Prepare the available voices for selection
    private func prepareVoicesForSelection() {
        // Get all available voices
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Get the list of hidden voice IDs from VoicePreferences
        let hiddenVoices = VoicePreferences.shared.getHiddenVoices()
        
        // Filter out hidden voices and focus on English voices
        let filtered = allVoices.filter { !hiddenVoices.contains($0.identifier) && $0.language.starts(with: "en") }
        
        // Convert to VoiceSelection objects
        availableVoices = filtered.map { voice in
            VoiceSelection(voice: voice, name: voice.name)
        }
        
        // Sort by quality (enhanced first) then by name
        availableVoices.sort { (a, b) in
            if a.voice.quality == b.voice.quality {
                return a.name < b.name
            }
            return a.voice.quality.rawValue > b.voice.quality.rawValue
        }
    }
    
    // Preview a voice
    private func playPreviewVoice(_ voice: AVSpeechSynthesisVoice) {
        // Stop any currently playing speech
        speechSynthesizer.stopSpeaking(at: .immediate)
        
        // Sample text for preview
        let sampleText = "Hello, I am \(voice.name)."
        
        // Update UI to show which voice is playing
        for index in availableVoices.indices {
            availableVoices[index].isPlaying = availableVoices[index].voice.identifier == voice.identifier
        }
        
        // Create and configure utterance
        let utterance = AVSpeechUtterance(string: sampleText)
        utterance.voice = voice
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // Start speaking
        speechSynthesizer.speak(utterance)
        
        // Reset the playing state after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            for index in self.availableVoices.indices {
                if self.availableVoices[index].voice.identifier == voice.identifier {
                    self.availableVoices[index].isPlaying = false
                }
            }
        }
    }
    
    // Change a character's voice
    private func changeCharacterVoice(to voice: AVSpeechSynthesisVoice) {
        // Update the character's voice in the dictionary
        if currentCharacterForVoiceChange == narratorName {
            // Update narrator voice
            narrationVoice = voice
            characterVoices[narratorName] = voice
        } else {
            // Update character voice
            characterVoices[currentCharacterForVoiceChange] = voice
        }
        
        // Restart reading with the new voice
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.readCurrentDialog()
        }
    }
}

// Wrapper for UIKit's PDFView with improved text highlighting
struct PDFViewWrapper: UIViewRepresentable {
    let pdfURL: URL
    let currentDialogText: String
    
    // Coordinator to handle PDF selection and highlighting
    class Coordinator: NSObject {
        var parent: PDFViewWrapper
        var highlightAnnotation: PDFAnnotation?
        var lastHighlightedText: String = ""
        
        init(parent: PDFViewWrapper) {
            self.parent = parent
        }
        
        // Create highlight for text, with improved search algorithm
        func highlightText(_ text: String, in pdfView: PDFView) {
            print("DEBUG PDFViewWrapper: Highlighting text: \(text.prefix(100))...")
            guard !text.isEmpty, let pdfDocument = pdfView.document else {
                print("DEBUG PDFViewWrapper: Cannot highlight - empty text or no document")
                return
            }
            
            // Special case for title/credits - just go to first page
            if text.contains("MELTDOWN") && text.contains("FADE IN") {
                print("DEBUG PDFViewWrapper: Special case for title/credits - going to first page")
                if let firstPage = pdfDocument.page(at: 0) {
                    pdfView.go(to: firstPage)
                    
                    // Create a general highlight for title area
                    let bounds = CGRect(x: 50, y: 650, width: 300, height: 50)
                    let highlight = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                    highlight.color = UIColor.yellow.withAlphaComponent(0.3)
                    
                    let path = UIBezierPath(rect: bounds)
                    highlight.add(path)
                    
                    firstPage.addAnnotation(highlight)
                    highlightAnnotation = highlight
                    
                    lastHighlightedText = text
                    print("DEBUG PDFViewWrapper: Added special highlight for title")
                    return
                }
            }
            
            // Special case for character descriptions
            var textToUse = text
            if text.contains("(") && text.contains(")") && text.contains(",") {
                // This is likely a character description
                // Try to extract just the character name for highlighting
                if let nameEndIndex = text.firstIndex(of: "(") {
                    let nameOnly = String(text[..<nameEndIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !nameOnly.isEmpty {
                        print("DEBUG PDFViewWrapper: Using character name only: \(nameOnly)")
                        textToUse = nameOnly 
                    }
                }
            }
            
            // Clean up text for better matching
            let cleanText = textToUse.replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)
                             .trimmingCharacters(in: .whitespacesAndNewlines)
                             .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            
            if cleanText.isEmpty { 
                print("DEBUG PDFViewWrapper: Text is empty after cleaning")
                return 
            }
            
            // If we're highlighting the same text, keep the current highlight
            if cleanText == lastHighlightedText && highlightAnnotation != nil {
                print("DEBUG PDFViewWrapper: Same text as last highlight, keeping current highlight")
                return
            }
            
            // Clear previous highlight
            removeHighlight(from: pdfView)
            
            print("DEBUG PDFViewWrapper: Trying various search strategies")
            
            // Try to find the text in the document with different search strategies
            
            // For character dialog, look for just the first part
            if cleanText.count > 20 && !cleanText.contains("INT.") && !cleanText.contains("EXT.") {
                // For dialogs, try searching for just the opening words
                let dialogFirstWords = cleanText.components(separatedBy: " ").prefix(4).joined(separator: " ")
                if dialogFirstWords.count > 10 {
                    print("DEBUG PDFViewWrapper: Strategy 0 - First few words of dialog")
                    if findAndHighlight(exactText: dialogFirstWords, in: pdfView, document: pdfDocument) {
                        lastHighlightedText = cleanText
                        print("DEBUG PDFViewWrapper: Highlighting successful with dialog first words")
                        return
                    }
                }
            }
            
            // Strategy 1: Direct match
            print("DEBUG PDFViewWrapper: Strategy 1 - Direct match")
            if !findAndHighlight(exactText: cleanText, in: pdfView, document: pdfDocument) {
                // Strategy 2: Try searching for first part
                print("DEBUG PDFViewWrapper: Strategy 2 - First part of text")
                let firstPart = cleanText.components(separatedBy: ".").first ?? cleanText
                if !findAndHighlight(exactText: firstPart, in: pdfView, document: pdfDocument) {
                    // Strategy 3: First 30 chars
                    print("DEBUG PDFViewWrapper: Strategy 3 - First 30 chars")
                    if cleanText.count > 30 {
                        let shortText = String(cleanText.prefix(30))
                        findAndHighlight(exactText: shortText, in: pdfView, document: pdfDocument)
                    }
                }
            }
            
            // Remember what we highlighted
            lastHighlightedText = cleanText
            
            // Report if we have a highlight
            print("DEBUG PDFViewWrapper: Highlighting successful: \(highlightAnnotation != nil)")
        }
        
        // Better text finding and highlighting algorithm
        private func findAndHighlight(exactText searchText: String, in pdfView: PDFView, document: PDFDocument) -> Bool {
            print("DEBUG PDFViewWrapper: Searching for text: \(searchText.prefix(50))...")
            
            // Get just the first important words for more reliable matching
            let words = searchText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            let firstWords = words.prefix(min(5, words.count)).joined(separator: " ")
            
            // Try several variations of the text for more reliable matching
            let searchVariations = [
                searchText,
                searchText.trimmingCharacters(in: .whitespacesAndNewlines),
                firstWords,
                // For character dialog, remove speaker direction
                searchText.replacingOccurrences(of: "\\([^\\)]+\\)", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                // Just the first word if it's substantial
                words.first ?? searchText
            ]
            
            // Search through each page manually as PDFDocument.findString behavior has changed
            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                guard let pageContent = page.string else { continue }
                
                print("DEBUG PDFViewWrapper: Checking page \(pageIndex+1) of \(document.pageCount)")
                
                // Try each variation of the search text
                for variation in searchVariations {
                    // Skip empty or too small variations
                    if variation.count < 5 { continue }
                    
                    // Just try a single word if it's character name
                    if variation.uppercased() == variation && variation.count < 20 {
                        // This might be a character name - just search for it directly
                        if let range = pageContent.range(of: variation, options: .caseInsensitive) {
                            print("DEBUG PDFViewWrapper: Found character name match on page \(pageIndex+1)!")
                            
                            // Convert to NSRange for selection
                            let nsRange = NSRange(range, in: pageContent)
                            
                            // Create selection from the range
                            if let selection = page.selection(for: nsRange) {
                                print("DEBUG PDFViewWrapper: Created selection successfully")
                                
                                // Get bounds for the selection
                                let bounds = selection.bounds(for: page)
                                
                                // Extend the bounds a bit for better visibility
                                let extendedBounds = CGRect(
                                    x: bounds.origin.x - 2, 
                                    y: bounds.origin.y - 2,
                                    width: bounds.width + 4, 
                                    height: bounds.height + 4
                                )
                                
                                // Scroll to the selection
                                pdfView.go(to: page)
                                
                                // Create a highlight annotation
                                let highlight = PDFAnnotation(bounds: extendedBounds, forType: .highlight, withProperties: nil)
                                highlight.color = UIColor.yellow.withAlphaComponent(0.5)
                                
                                // Add the path for the bounds
                                let path = UIBezierPath(rect: extendedBounds)
                                highlight.add(path)
                                
                                // Add to page and save reference
                                page.addAnnotation(highlight)
                                highlightAnnotation = highlight
                                
                                print("DEBUG PDFViewWrapper: Successfully added character highlight annotation")
                                return true
                            }
                        }
                    }
                    
                    // For regular text, try just searching for the beginning
                    let searchSubstring = String(variation.prefix(min(variation.count, 30)))
                    
                    // Check if this page contains our text
                    if let range = pageContent.range(of: searchSubstring, options: .caseInsensitive) {
                        print("DEBUG PDFViewWrapper: Found text match on page \(pageIndex+1)!")
                        
                        // Convert to NSRange for selection
                        let nsRange = NSRange(range, in: pageContent)
                        
                        // Create selection from the range
                        if let selection = page.selection(for: nsRange) {
                            print("DEBUG PDFViewWrapper: Created selection successfully")
                            
                            // Get bounds for the selection
                            let bounds = selection.bounds(for: page)
                            print("DEBUG PDFViewWrapper: Selection bounds: \(bounds)")
                            
                            // Extend the bounds a bit for better visibility
                            let extendedBounds = CGRect(
                                x: bounds.origin.x - 2, 
                                y: bounds.origin.y - 2,
                                width: bounds.width + 4, 
                                height: bounds.height + 4
                            )
                            
                            // Scroll to the selection
                            pdfView.go(to: page)
                            
                            // Create a highlight annotation
                            let highlight = PDFAnnotation(bounds: extendedBounds, forType: .highlight, withProperties: nil)
                            highlight.color = UIColor.yellow.withAlphaComponent(0.5)
                            
                            // Add the path for the bounds
                            let path = UIBezierPath(rect: extendedBounds)
                            highlight.add(path)
                            
                            // Add to page and save reference
                            page.addAnnotation(highlight)
                            highlightAnnotation = highlight
                            
                            print("DEBUG PDFViewWrapper: Successfully added highlight annotation")
                            return true
                        } else {
                            print("DEBUG PDFViewWrapper: Could not create selection from range")
                        }
                    }
                }
            }
            
            print("DEBUG PDFViewWrapper: Text not found in any page")
            return false
        }
        
        // Remove existing highlight
        func removeHighlight(from pdfView: PDFView) {
            if let highlight = highlightAnnotation, let page = highlight.page {
                page.removeAnnotation(highlight)
                highlightAnnotation = nil
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
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
        // Update PDF document if URL changes
        if let document = uiView.document, document.documentURL != pdfURL {
            if let newDocument = PDFDocument(url: pdfURL) {
                uiView.document = newDocument
            }
        } else if uiView.document == nil {
            if let newDocument = PDFDocument(url: pdfURL) {
                uiView.document = newDocument
            }
        }
        
        // Highlight the current text with slight delay to ensure view is ready
        DispatchQueue.main.async {
            context.coordinator.highlightText(currentDialogText, in: uiView)
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