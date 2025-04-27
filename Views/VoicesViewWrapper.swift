import SwiftUI
import AVFoundation
import Foundation
import UIKit

// Voices View Wrapper
struct VoicesViewWrapper: View {
    var moveToNextScreen: () -> Void
    @State private var voices: [AVSpeechSynthesisVoice] = []
    @State private var selectedVoice: AVSpeechSynthesisVoice?
    @State private var isPlaying: String? = nil
    @State private var editMode: EditMode = .inactive
    @State private var hiddenVoices: [String] = UserDefaults.standard.stringArray(forKey: "hiddenVoices") ?? []
    
    private let sampleText = "To be or not to be, that is the question."
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    moveToNextScreen()
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                Text("Premium Voice Selection")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Edit button
                Button(action: {
                    withAnimation {
                        editMode = editMode == .active ? .inactive : .active
                    }
                }) {
                    Text(editMode == .active ? "Done" : "Edit")
                        .padding(.horizontal)
                }
            }
            .padding(.top, 30)
            
            VStack(spacing: 4) {
                Text("Choose a high-quality voice for your characters")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom)
            
            if voices.isEmpty {
                Spacer()
                
                VStack(spacing: 30) {
                    Image(systemName: "exclamationmark.circle")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.orange)
                    
                    Text("No Premium Voices Found")
                        .font(.headline)
                    
                    Text("Please download enhanced voices in iOS Settings > Accessibility > Spoken Content > Voices")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                        
                    Button(action: {
                        openSettings()
                    }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Open Settings")
                        }
                        .frame(minWidth: 200)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
                
                Spacer()
            } else {
                List {
                    ForEach(filteredVoices, id: \.identifier) { voice in
                        VoiceRowView(
                            voice: voice,
                            isPlaying: isPlaying == voice.identifier,
                            sampleText: sampleText,
                            onPlay: {
                                playVoice(voice)
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if editMode == .inactive {
                                selectedVoice = voice
                            }
                        }
                        .listRowBackground(selectedVoice?.identifier == voice.identifier ? Color.blue.opacity(0.1) : Color.clear)
                        .swipeActions(edge: .trailing) {
                            // Implement direct hide/unhide without VoicePreferences
                            Button(role: .destructive) {
                                hideVoice(voice)
                            } label: {
                                Label("Hide", systemImage: "eye.slash")
                            }
                        }
                    }
                }
                .environment(\.editMode, $editMode)
                .environment(\.defaultMinListRowHeight, 80) // Give more height to rows for better tapping
            }
            
            if editMode == .inactive && !voices.isEmpty {
                if hiddenVoices.count > 0 {
                    Button(action: {
                        hiddenVoices = []
                    }) {
                        Text("Reset Hidden Voices")
                            .foregroundColor(.blue)
                            .padding(.vertical, 10)
                    }
                }
                
                Button(action: {
                    // Save selected voice and continue to cast view
                    moveToNextScreen()
                }) {
                    Text("Continue to Cast Selection")
                        .frame(minWidth: 200)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.bottom, 20)
                .disabled(selectedVoice == nil)
                .opacity(selectedVoice == nil ? 0.5 : 1.0)
            }
        }
        .onAppear {
            loadVoices()
        }
    }
    
    // Return only voices that aren't hidden
    private var filteredVoices: [AVSpeechSynthesisVoice] {
        if editMode == .active {
            // When in edit mode, show all voices
            return voices
        } else {
            // When not in edit mode, filter out hidden voices
            return voices.filter { !hiddenVoices.contains($0.identifier) }
        }
    }
    
    private func hideVoice(_ voice: AVSpeechSynthesisVoice) {
        // Add to hidden voices if not already present
        if !hiddenVoices.contains(voice.identifier) {
            hiddenVoices.append(voice.identifier)
            // Save to UserDefaults
            UserDefaults.standard.set(hiddenVoices, forKey: "hiddenVoices")
        }
        
        // If the hidden voice was selected, deselect it
        if selectedVoice?.identifier == voice.identifier {
            selectedVoice = nil
        }
    }
    
    private func unhideVoice(_ voice: AVSpeechSynthesisVoice) {
        // Remove from hidden voices if present
        if let index = hiddenVoices.firstIndex(of: voice.identifier) {
            hiddenVoices.remove(at: index)
            // Save to UserDefaults
            UserDefaults.standard.set(hiddenVoices, forKey: "hiddenVoices")
        }
    }
    
    private func loadVoices() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Filter to only show English premium/enhanced voices
        voices = allVoices.filter { voice in
            // Must be English language
            guard voice.language.starts(with: "en") else { return false }
            
            // Must be enhanced quality or have "premium" in the name
            return voice.quality == .enhanced || 
                   voice.name.lowercased().contains("premium") ||
                   voice.name.lowercased().contains("enhanced")
        }
        
        // Sort by name
        voices.sort { $0.name < $1.name }
        
        print("Loaded \(voices.count) premium English voices")
        for voice in voices {
            print("Voice: \(voice.name), ID: \(voice.identifier), Quality: \(voice.quality.rawValue)")
        }
        
        // If no voices found, try loading all voices
        if voices.isEmpty {
            loadAllVoices()
        }
    }
    
    // Fallback to load all English voices if no premium voices are available
    private func loadAllVoices() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Filter to only show English voices
        voices = allVoices.filter { $0.language.starts(with: "en") }
        
        // Sort by quality first, then by name
        voices.sort { (voice1, voice2) -> Bool in
            if voice1.quality == voice2.quality {
                return voice1.name < voice2.name
            }
            return voice1.quality.rawValue > voice2.quality.rawValue
        }
        
        print("Loaded \(voices.count) English voices (all qualities)")
        for voice in voices {
            print("Voice: \(voice.name), ID: \(voice.identifier), Quality: \(voice.quality.rawValue)")
        }
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
    
    private func openSettings() {
        if let url = URL(string: "App-Prefs:root=ACCESSIBILITY&path=SPEECH") {
           UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}