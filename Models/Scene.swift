import Foundation

class Scene {
    var heading: String
    var description: String
    var location: String
    var timeOfDay: String
    var sceneNumber: String?
    var dialogs: [Dialog] = []
    
    init(heading: String, description: String, location: String, timeOfDay: String, sceneNumber: String? = nil) {
        self.heading = heading
        self.description = description
        self.location = location
        self.timeOfDay = timeOfDay
        self.sceneNumber = sceneNumber
    }
    
    func addDialog(character: String, text: String) {
        let dialog = Dialog(character: character, text: text)
        dialogs.append(dialog)
    }
    
    class Dialog {
        var character: String
        var text: String
        var containsStageDirections: Bool
        
        // Add a property to track whether this dialog should stop auto-advance
        var shouldHaltAutoAdvance: Bool = false
        
        init(character: String, text: String) {
            self.character = character
            self.text = text
            self.containsStageDirections = text.range(of: "\\(.*?\\)", options: .regularExpression) != nil
            
            // Check if this dialog contains text that should stop auto-advance
            self.shouldHaltAutoAdvance = text.contains("SARAH") || 
                                         text.contains("Sarah") || 
                                         text.contains("##STOP_AFTER##")
        }
    }
}