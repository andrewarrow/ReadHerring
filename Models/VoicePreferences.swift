import Foundation
import AVFoundation

// Extension to make AVSpeechSynthesizer accessible globally
extension AVSpeechSynthesizer {
    static let shared = AVSpeechSynthesizer()
}

class VoicePreferences {
    static let shared = VoicePreferences()
    private let hiddenVoicesKey = "hiddenVoices"
    
    private init() {}
    
    // Load hidden voices from UserDefaults
    func getHiddenVoices() -> [String] {
        return UserDefaults.standard.stringArray(forKey: hiddenVoicesKey) ?? []
    }
    
    // Save hidden voices to UserDefaults
    func saveHiddenVoices(_ voiceIds: [String]) {
        UserDefaults.standard.set(voiceIds, forKey: hiddenVoicesKey)
    }
    
    // Hide a specific voice
    func hideVoice(_ voiceId: String) {
        var hiddenVoices = getHiddenVoices()
        if !hiddenVoices.contains(voiceId) {
            hiddenVoices.append(voiceId)
            saveHiddenVoices(hiddenVoices)
        }
    }
    
    // Unhide a specific voice
    func unhideVoice(_ voiceId: String) {
        var hiddenVoices = getHiddenVoices()
        if let index = hiddenVoices.firstIndex(of: voiceId) {
            hiddenVoices.remove(at: index)
            saveHiddenVoices(hiddenVoices)
        }
    }
    
    // Check if a voice is hidden
    func isVoiceHidden(_ voiceId: String) -> Bool {
        return getHiddenVoices().contains(voiceId)
    }
    
    // Clear all hidden voices
    func clearAllHiddenVoices() {
        saveHiddenVoices([])
    }
}