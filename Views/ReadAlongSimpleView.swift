import SwiftUI
import AVFoundation

struct ReadAlongSimpleView: View {
    let scenes: [Scene]
    
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
        // Ultra-minimal UI to avoid Metal framework issues
        VStack {
            // Close button at top
            HStack {
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
                
                Spacer()
                
                Text("Read Along")
                    .bold()
                
                Spacer()
            }
            
            Spacer().frame(height: 20)
            
            // Prev/Next buttons
            HStack {
                Button("← Prev") {
                    moveToPrevious()
                }
                .disabled(!hasPrevious)
                .padding()
                
                Spacer()
                
                Button("Next →") {
                    moveToNext()
                }
                .disabled(!hasNext)
                .padding()
            }
            
            Spacer().frame(height: 20)
            
            // Character name and dialog text
            if let dialog = currentDialog {
                Text(dialog.character)
                    .bold()
                    .font(.title2)
                    .padding(.bottom, 5)
                
                VStack(alignment: .leading) {
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
                        }
                    }
                }
                .padding()
            } else {
                Text("No dialog available")
                    .italic()
                    .padding()
            }
            
            Spacer()
            
            // Scene counter
            Text("Scene \(currentSceneIndex+1) of \(scenes.count)")
                .padding()
        }
        .onAppear {
            assignVoices()
            readCurrentDialog()
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
        let availableVoices = AVSpeechSynthesisVoice.speechVoices()
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

struct ReadAlongSimpleView_Previews: PreviewProvider {
    static var previews: some View {
        // Create sample data
        let scene = Scene(heading: "INT. OFFICE - DAY", description: "The office is busy.", location: "OFFICE", timeOfDay: "DAY")
        scene.addDialog(character: "SARAH", text: "Has anyone seen the demo unit? (horrified) Anyone?")
        scene.addDialog(character: "MIKE", text: "I swear I put it in the conference room last night!")
        
        return ReadAlongSimpleView(scenes: [scene])
    }
}