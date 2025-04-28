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
    
    // Get premium/enhanced English voices that aren't hidden
    // Uses the same filtering logic as VoicesViewWrapper
    func getAvailableVoices() -> [AVSpeechSynthesisVoice] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let hiddenVoices = voicePreferences.getHiddenVoices()
        
        // Filter to only show English premium/enhanced voices that aren't hidden
        let filteredVoices = allVoices.filter { voice in
            // Must be English language
            guard voice.language.starts(with: "en") else { return false }
            
            // Must be enhanced quality or have "premium" in the name
            let isPremiumOrEnhanced = voice.quality == .enhanced || 
                                      voice.name.lowercased().contains("premium") ||
                                      voice.name.lowercased().contains("enhanced")
            
            // Must not be hidden
            let isNotHidden = !hiddenVoices.contains(voice.identifier)
            
            return isPremiumOrEnhanced && isNotHidden
        }
        
        // If no premium voices found, fall back to any English voices
        if filteredVoices.isEmpty {
            return getFallbackVoices()
        }
        
        // Sort by name
        return filteredVoices.sorted { $0.name < $1.name }
    }
    
    // Fallback to get any English voices (not hidden) if no premium voices available
    private func getFallbackVoices() -> [AVSpeechSynthesisVoice] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let hiddenVoices = voicePreferences.getHiddenVoices()
        
        // Filter to only show English voices that aren't hidden
        let filteredVoices = allVoices.filter { voice in
            voice.language.starts(with: "en") && !hiddenVoices.contains(voice.identifier)
        }
        
        // Sort by quality first, then by name
        return filteredVoices.sorted { (voice1, voice2) -> Bool in
            if voice1.quality == voice2.quality {
                return voice1.name < voice2.name
            }
            return voice1.quality.rawValue > voice2.quality.rawValue
        }
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
        
        // Find the voice with this ID from all voices (in case it was assigned but later hidden)
        if let voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.identifier == voiceId }) {
            // Check if this voice is still in our available voices list
            let availableVoices = getAvailableVoices()
            if availableVoices.contains(where: { $0.identifier == voiceId }) {
                return voice
            } else {
                // If this voice is no longer available (e.g., it was hidden), assign a new random voice
                if let newVoice = getRandomVoice() {
                    characterVoiceMap[character] = newVoice.identifier
                    return newVoice
                }
            }
        }
        
        // If we couldn't find the voice, get a random one
        return getRandomVoice()
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