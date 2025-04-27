import Foundation

extension Scene {
    class Dialog {
        var character: String
        var text: String
        var containsStageDirections: Bool
        
        init(character: String, text: String) {
            self.character = character
            self.text = text
            self.containsStageDirections = text.range(of: "\\(.*?\\)", options: .regularExpression) != nil
        }
    }
    
    var dialogs: [Dialog] = []
    
    func addDialog(character: String, text: String) {
        let dialog = Dialog(character: character, text: text)
        dialogs.append(dialog)
    }
}