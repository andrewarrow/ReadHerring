import SwiftUI
import AVFoundation

struct ReadAlongNavigationView: View {
    let scenes: [Scene]
    
    @State private var currentSceneIndex: Int = 0
    @State private var currentDialogIndex: Int = 0
    @State private var characterVoices: [String: AVSpeechSynthesisVoice] = [:]
    @State private var narrationVoice: AVSpeechSynthesisVoice?
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    
    private var currentScene: Scene {
        scenes[currentSceneIndex]
    }
    
    private var currentDialog: Scene.Dialog? {
        guard !currentScene.dialogs.isEmpty, currentDialogIndex < currentScene.dialogs.count else {
            return nil
        }
        return currentScene.dialogs[currentDialogIndex]
    }
    
    private var hasPrevious: Bool {
        if currentDialogIndex > 0 {
            return true
        }
        return currentSceneIndex > 0
    }
    
    private var hasNext: Bool {
        if currentDialogIndex < currentScene.dialogs.count - 1 {
            return true
        }
        return currentSceneIndex < scenes.count - 1
    }
    
    var body: some View {
        VStack {
            // Navigation buttons
            HStack {
                Button(action: {
                    moveToPrevious()
                }) {
                    Text("Prev")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!hasPrevious)
                
                Spacer()
                
                Button(action: {
                    moveToNext()
                }) {
                    Text("Next")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!hasNext)
            }
            .padding()
            
            // Current dialog display
            if let dialog = currentDialog {
                // Only show the dialog text, not the character name
                VStack(alignment: .leading) {
                    dialogView(for: dialog)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .onAppear {
            assignVoices()
            readCurrentDialog()
        }
    }
    
    private func dialogView(for dialog: Scene.Dialog) -> some View {
        let components = splitText(dialog.text)
        
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(components, id: \.self) { component in
                if component.hasPrefix("(") && component.hasSuffix(")") {
                    // Stage direction
                    Text(component)
                        .italic()
                        .foregroundColor(.gray)
                } else {
                    // Regular dialog text
                    Text(component)
                }
            }
        }
    }
    
    private func splitText(_ text: String) -> [String] {
        var result: [String] = []
        var currentText = ""
        var inParenthesis = false
        
        for character in text {
            if character == "(" && !inParenthesis {
                if !currentText.isEmpty {
                    result.append(currentText.trimmingCharacters(in: .whitespacesAndNewlines))
                    currentText = ""
                }
                inParenthesis = true
                currentText.append(character)
            } else if character == ")" && inParenthesis {
                currentText.append(character)
                result.append(currentText.trimmingCharacters(in: .whitespacesAndNewlines))
                currentText = ""
                inParenthesis = false
            } else {
                currentText.append(character)
            }
        }
        
        if !currentText.isEmpty {
            result.append(currentText.trimmingCharacters(in: .whitespacesAndNewlines))
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
            currentDialogIndex = scenes[currentSceneIndex].dialogs.count - 1
        }
        
        readCurrentDialog()
    }
    
    private func moveToNext() {
        if currentDialogIndex < currentScene.dialogs.count - 1 {
            currentDialogIndex += 1
        } else if currentSceneIndex < scenes.count - 1 {
            currentSceneIndex += 1
            currentDialogIndex = 0
        }
        
        readCurrentDialog()
    }
}

struct ReadAlongNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        // Create sample data
        let scene = Scene(heading: "INT. OFFICE - DAY", description: "The office is busy.", location: "OFFICE", timeOfDay: "DAY")
        scene.addDialog(character: "SARAH", text: "Has anyone seen the demo unit? (horrified) Anyone?")
        scene.addDialog(character: "MIKE", text: "I swear I put it in the conference room last night!")
        
        return ReadAlongNavigationView(scenes: [scene])
    }
}