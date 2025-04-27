import SwiftUI
import AVFoundation
import PDFKit

struct ReadAlongSimpleView: View {
    let scenes: [Scene]
    var pdfURL: URL? = nil
    
    @State private var currentSceneIndex: Int = 0
    @State private var currentDialogIndex: Int = 0
    @State private var characterVoices: [String: AVSpeechSynthesisVoice] = [:]
    @State private var narrationVoice: AVSpeechSynthesisVoice?
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @Environment(\.presentationMode) var presentationMode
    
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
            if let url = pdfURL {
                SimpleReadAlongPDFWrapper(pdfURL: url)
                    .edgesIgnoringSafeArea(.all)
            }
            
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
                        Text(dialog.character)
                            .bold()
                            .font(.headline)
                            .padding(.bottom, 5)
                        
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
            assignVoices()
            readCurrentDialog()
        }
    }
    
    @ViewBuilder
    private func dialogBox(for dialog: Scene.Dialog) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Split text to handle stage directions
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
        .padding()
        .background(Color.white)
        .border(Color.black, width: 1)
        .cornerRadius(4)
        .frame(maxWidth: 500)
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
        
        // Set a random voice for narration
        narrationVoice = availableVoices.randomElement()
        
        // Get unique character names
        var uniqueCharacters = Set<String>()
        for scene in scenes {
            for dialog in scene.dialogs {
                uniqueCharacters.insert(dialog.character)
            }
        }
        
        // Assign random voices to each character
        for character in uniqueCharacters {
            if let randomVoice = availableVoices.randomElement() {
                characterVoices[character] = randomVoice
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
        
        // Set the voice based on the character
        if let voice = characterVoices[dialog.character] {
            utterance.voice = voice
        } else {
            utterance.voice = narrationVoice
        }
        
        // Adjust speech properties
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // Start speaking
        speechSynthesizer.speak(utterance)
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
        
        readCurrentDialog()
    }
}

// Simple PDF view wrapper for the simplified read along view
struct SimpleReadAlongPDFWrapper: UIViewRepresentable {
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

struct ReadAlongSimpleView_Previews: PreviewProvider {
    static var previews: some View {
        // Create sample data
        let scene1 = Scene(heading: "STARTUP MELTDOWN", description: "Written by Assistant", location: "", timeOfDay: "")
        
        let scene2 = Scene(heading: "INT. TECH STARTUP OFFICE - MORNING", 
                         description: "The office is buzzing with nervous energy.",
                         location: "TECH STARTUP OFFICE", 
                         timeOfDay: "MORNING")
        
        scene2.addDialog(character: "SARAH", text: "Has anyone seen the demo unit? (horrified) Anyone?")
        scene2.addDialog(character: "MIKE", text: "I swear I put it in the conference room last night!")
        
        // Create URL to sample PDF
        let samplePDFURL = Bundle.main.url(forResource: "fade", withExtension: "pdf") ?? 
                          URL(fileURLWithPath: "/Users/aa/os/ReadHerring/fade.pdf")
        
        return ReadAlongSimpleView(scenes: [scene1, scene2], pdfURL: samplePDFURL)
    }
}