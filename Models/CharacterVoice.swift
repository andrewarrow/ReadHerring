import Foundation
import AVFoundation

class CharacterVoices {
    static let shared = CharacterVoices()
    
    private let voicePreferences = VoicePreferences.shared
    private var characterVoiceMap: [String: String] = [:] // Character name to voice ID
    
    // Key for narrator in the mapping
    static let NARRATOR_KEY = "NARRATOR"
    
    private init() {
        // Initialize with empty mappings
    }
    
    // Get available voices (not hidden)
    func getAvailableVoices() -> [AVSpeechSynthesisVoice] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let hiddenVoices = voicePreferences.getHiddenVoices()
        
        // Filter to only show English voices that aren't hidden
        return allVoices.filter { voice in
            voice.language.starts(with: "en") && !hiddenVoices.contains(voice.identifier)
        }.sorted { $0.name < $1.name }
    }
    
    // Get a random voice from available voices
    func getRandomVoice() -> AVSpeechSynthesisVoice? {
        let availableVoices = getAvailableVoices()
        guard !availableVoices.isEmpty else { return nil }
        return availableVoices.randomElement()
    }
    
    // Get the voice for a character, assigning a random one if none exists
    func getVoiceFor(character: String) -> AVSpeechSynthesisVoice? {
        // If no voice has been assigned to this character yet, assign a random one
        if characterVoiceMap[character] == nil {
            if let randomVoice = getRandomVoice() {
                characterVoiceMap[character] = randomVoice.identifier
            }
        }
        
        // Get the voice ID for the character
        guard let voiceId = characterVoiceMap[character] else { return getRandomVoice() }
        
        // Find the voice with this ID
        return AVSpeechSynthesisVoice.speechVoices().first { $0.identifier == voiceId }
    }
    
    // Set a specific voice for a character
    func setVoice(character: String, voice: AVSpeechSynthesisVoice) {
        characterVoiceMap[character] = voice.identifier
    }
    
    // Get name of voice for a character (for display)
    func getVoiceNameFor(character: String) -> String {
        guard let voiceId = characterVoiceMap[character],
              let voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.identifier == voiceId }) else {
            return "Not assigned"
        }
        return voice.name
    }
}