import SwiftUI
import AVFoundation

struct VoiceSelectionView: View {
    let character: String
    @Binding var selectedVoiceId: String?
    @State private var voices: [AVSpeechSynthesisVoice] = []
    @State private var localSelectedVoice: AVSpeechSynthesisVoice?
    @State private var isPlaying: String? = nil
    @Environment(\.dismiss) private var dismiss
    
    private let sampleText = "This is a voice sample for character selection."
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Select Voice for \(character)")
                    .font(.headline)
                    .padding()
                
                if voices.isEmpty {
                    Text("No voices available")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(voices, id: \.identifier) { voice in
                            VoiceSelectionRow(
                                voice: voice,
                                isSelected: localSelectedVoice?.identifier == voice.identifier,
                                isPlaying: isPlaying == voice.identifier,
                                onPlay: {
                                    playVoice(voice)
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                localSelectedVoice = voice
                            }
                        }
                    }
                }
                
                Button("Confirm Selection") {
                    // Update the selected voice ID binding
                    selectedVoiceId = localSelectedVoice?.identifier
                    
                    // Dismiss the modal
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(localSelectedVoice == nil)
                .padding()
            }
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
            .onAppear {
                loadVoices()
                // Initialize local selection from binding if available
                if let id = selectedVoiceId {
                    localSelectedVoice = voices.first(where: { $0.identifier == id })
                }
            }
        }
    }
    
    private func loadVoices() {
        // Get available voices (not hidden)
        voices = CharacterVoices.shared.getAvailableVoices()
    }
    
    private func playVoice(_ voice: AVSpeechSynthesisVoice) {
        // Stop any currently playing speech
        if isPlaying != nil {
            AVSpeechSynthesizer.shared.stopSpeaking(at: .immediate)
        }
        
        // Set the voice as playing
        isPlaying = voice.identifier
        
        // Create and configure utterance
        let utterance = AVSpeechUtterance(string: sampleText)
        utterance.voice = voice
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // Start speaking
        AVSpeechSynthesizer.shared.speak(utterance)
        
        // Set timer to stop playing status after a few seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if self.isPlaying == voice.identifier {
                self.isPlaying = nil
            }
        }
    }
}

struct VoiceSelectionRow: View {
    let voice: AVSpeechSynthesisVoice
    let isSelected: Bool
    let isPlaying: Bool
    let onPlay: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(voice.name)
                    .font(.headline)
                    .foregroundColor(isSelected ? .blue : .primary)
                
                Text(voice.language)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(isPlaying ? .red : .blue)
            }
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .padding(.leading, 8)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }
}