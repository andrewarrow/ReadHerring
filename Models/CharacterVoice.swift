import Foundation
import AVFoundation

class CharacterVoices {
    static let shared = CharacterVoices()
    
    private let voicePreferences = VoicePreferences.shared
    private var characterVoiceMap: [String: String] = [:] // Character name to voice ID
    
    // Track which voices have been assigned by gender
    private var usedMaleVoices: Set<String> = []
    private var usedFemaleVoices: Set<String> = []
    private var usedNeutralVoices: Set<String> = []
    
    // Key for narrator in the mapping
    static let NARRATOR_KEY = "NARRATOR"
    
    private init() {
        // Initialize with empty mappings
    }
    
    // Reset the used voice trackers (called when reassigning all voices)
    func resetUsedVoices() {
        usedMaleVoices.removeAll()
        usedFemaleVoices.removeAll()
        usedNeutralVoices.removeAll()
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
    
    // Get a random voice from available voices, optionally filtered by gender
    // Prioritizes voices that have not been used yet for this gender
    func getRandomVoice(gender: String? = nil) -> AVSpeechSynthesisVoice? {
        let availableVoices = getAvailableVoices()
        guard !availableVoices.isEmpty else { return nil }
        
        // Define function to identify male voices
        let isMaleVoice = { (voice: AVSpeechSynthesisVoice) -> Bool in
            let name = voice.name.lowercased()
            return name.contains("male") || 
                   name.contains("man") || 
                   name.contains("guy") || 
                   name.contains("boy") ||
                   (name.contains("tom") && !name.contains("custom"))
        }
        
        // Define function to identify female voices
        let isFemaleVoice = { (voice: AVSpeechSynthesisVoice) -> Bool in
            let name = voice.name.lowercased()
            return name.contains("female") || 
                   name.contains("woman") || 
                   name.contains("girl") || 
                   name.contains("lady") ||
                   name.contains("nicki") ||
                   name.contains("samantha") ||
                   name.contains("karen") ||
                   name.contains("tessa")
        }
        
        if let gender = gender {
            // Filter voices by likely gender based on voice name
            let genderVoices: [AVSpeechSynthesisVoice]
            let usedVoices: Set<String>
            
            if gender == "M" {
                genderVoices = availableVoices.filter(isMaleVoice)
                usedVoices = usedMaleVoices
            } else if gender == "F" {
                genderVoices = availableVoices.filter(isFemaleVoice)
                usedVoices = usedFemaleVoices
            } else {
                // For random gender, try to use any voices not used by either gender
                let neutralVoices = availableVoices.filter { voice in
                    !isMaleVoice(voice) && !isFemaleVoice(voice)
                }
                genderVoices = neutralVoices.isEmpty ? availableVoices : neutralVoices
                usedVoices = usedNeutralVoices
            }
            
            // If no voices match gender, fallback to any available voice
            if genderVoices.isEmpty {
                return availableVoices.randomElement()
            }
            
            // First try unused voices for this gender
            let unusedVoices = genderVoices.filter { !usedVoices.contains($0.identifier) }
            
            // If we have unused voices, return one of them
            if !unusedVoices.isEmpty {
                let selectedVoice = unusedVoices.randomElement()!
                
                // Mark this voice as used for this gender
                if gender == "M" {
                    usedMaleVoices.insert(selectedVoice.identifier)
                } else if gender == "F" {
                    usedFemaleVoices.insert(selectedVoice.identifier)
                } else {
                    usedNeutralVoices.insert(selectedVoice.identifier)
                }
                
                return selectedVoice
            }
            
            // If all voices have been used, reset and start over
            // (This ensures we cycle through all voices before repeating)
            if gender == "M" {
                usedMaleVoices.removeAll()
            } else if gender == "F" {
                usedFemaleVoices.removeAll()
            } else {
                usedNeutralVoices.removeAll()
            }
            
            // Choose any voice from the gender-appropriate pool
            let selectedVoice = genderVoices.randomElement()!
            
            // Mark it as used
            if gender == "M" {
                usedMaleVoices.insert(selectedVoice.identifier)
            } else if gender == "F" {
                usedFemaleVoices.insert(selectedVoice.identifier)
            } else {
                usedNeutralVoices.insert(selectedVoice.identifier)
            }
            
            return selectedVoice
        }
        
        // No gender filter, return any random voice that hasn't been used
        let allUsedVoices = usedMaleVoices.union(usedFemaleVoices).union(usedNeutralVoices)
        let unusedVoices = availableVoices.filter { !allUsedVoices.contains($0.identifier) }
        
        if !unusedVoices.isEmpty {
            return unusedVoices.randomElement()
        }
        
        // All voices have been used, reset tracking and return random voice
        resetUsedVoices()
        return availableVoices.randomElement()
    }
    
    // Get the voice for a character, assigning a random one if none exists
    func getVoiceFor(character: String, gender: String? = nil) -> AVSpeechSynthesisVoice? {
        // If no voice has been assigned to this character yet, assign one based on gender
        if characterVoiceMap[character] == nil {
            if let randomVoice = getRandomVoice(gender: gender) {
                characterVoiceMap[character] = randomVoice.identifier
                
                // Track this voice as used for its gender
                if let gender = gender {
                    if gender == "M" {
                        usedMaleVoices.insert(randomVoice.identifier)
                    } else if gender == "F" {
                        usedFemaleVoices.insert(randomVoice.identifier)
                    } else {
                        usedNeutralVoices.insert(randomVoice.identifier)
                    }
                }
            }
        }
        
        // Get the voice ID for the character
        guard let voiceId = characterVoiceMap[character] else { return getRandomVoice(gender: gender) }
        
        // Find the voice with this ID from all voices (in case it was assigned but later hidden)
        if let voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.identifier == voiceId }) {
            // Check if this voice is still in our available voices list
            let availableVoices = getAvailableVoices()
            if availableVoices.contains(where: { $0.identifier == voiceId }) {
                return voice
            } else {
                // If this voice is no longer available (e.g., it was hidden), assign a new random voice
                if let newVoice = getRandomVoice(gender: gender) {
                    characterVoiceMap[character] = newVoice.identifier
                    
                    // Track this voice as used for its gender
                    if let gender = gender {
                        if gender == "M" {
                            usedMaleVoices.insert(newVoice.identifier)
                        } else if gender == "F" {
                            usedFemaleVoices.insert(newVoice.identifier)
                        } else {
                            usedNeutralVoices.insert(newVoice.identifier)
                        }
                    }
                    
                    return newVoice
                }
            }
        }
        
        // If we couldn't find the voice, get a random one
        return getRandomVoice(gender: gender)
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