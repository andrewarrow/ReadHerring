import SwiftUI
import PDFKit
import AVFoundation

struct ReadAlongView: View {
    var pdfURL: URL
    var scenes: [Scene]
    
    @State private var currentSceneIndex: Int = 0
    @State private var currentDialogIndex: Int = 0
    @State private var characterVoices: [String: AVSpeechSynthesisVoice] = [:]
    @State private var narrationVoice: AVSpeechSynthesisVoice?
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @Environment(\.presentationMode) var presentationMode
    
    // Special narrator name for scene headings and descriptions
    private let narratorName = "NARRATOR"
    
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
                
                // Prev/Next buttons
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
            
            // Begin reading
            readCurrentDialog()
        }
    }
    
    @ViewBuilder
    private func dialogBox(for dialog: Scene.Dialog) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Check if this is narrator content (scene heading or description)
            if isNarrationDialog(dialog) {
                // Render narrator content with different styling
                Text(dialog.text)
                    .italic()
                    .foregroundColor(dialog.text == dialog.text.uppercased() ? .blue : .gray)
                    .font(dialog.text == dialog.text.uppercased() ? .headline : .body)
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
        
        // Clean text by removing stage directions (text in parentheses)
        let cleanText = dialog.text.replacingOccurrences(
            of: "\\(.*?\\)",
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip if nothing to read
        if cleanText.isEmpty { return }
        
        // Stop any ongoing speech
        speechSynthesizer.stopSpeaking(at: .immediate)
        
        // Create utterance with the clean text
        let utterance = AVSpeechUtterance(string: cleanText)
        
        // Get the appropriate voice based on content type
        if isNarrationDialog(dialog) {
            // Use narrator voice for scene headings and descriptions
            utterance.voice = characterVoices[narratorName] ?? narrationVoice
        } else {
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
        
        // Start speaking
        speechSynthesizer.speak(utterance)
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
    
    // Process scenes to ensure they have heading and description narration
    private func processScenes() {
        for (index, scene) in scenes.enumerated() {
            // Check if scene already has narrator dialog entries
            let hasNarratorEntries = scene.dialogs.contains { dialog in
                return dialog.character == narratorName
            }
            
            // If no narrator entries, add them for heading and description
            if !hasNarratorEntries {
                // Add scene heading as dialog from narrator if not empty
                if !scene.heading.isEmpty {
                    let headingDialog = Scene.Dialog(character: narratorName, text: scene.heading)
                    
                    // Insert at beginning of dialog list
                    if !scene.dialogs.isEmpty {
                        scene.dialogs.insert(headingDialog, at: 0)
                    } else {
                        scene.dialogs.append(headingDialog)
                    }
                }
                
                // Add scene description as dialog from narrator if not empty
                if !scene.description.isEmpty {
                    let descriptionDialog = Scene.Dialog(character: narratorName, text: scene.description)
                    
                    // Insert after heading or at beginning if no heading
                    if scene.dialogs.isEmpty {
                        scene.dialogs.append(descriptionDialog)
                    } else if scene.dialogs[0].character == narratorName {
                        scene.dialogs.insert(descriptionDialog, at: 1)
                    } else {
                        scene.dialogs.insert(descriptionDialog, at: 0)
                    }
                }
            }
        }
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