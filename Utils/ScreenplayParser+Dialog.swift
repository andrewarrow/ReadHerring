import Foundation

extension ScreenplayParser {
    // Parse screenplay into dialogs and assign them to appropriate scenes
    static func parseDialogsFromText(scenes: [Scene], rawText: String) {
        let lines = rawText.components(separatedBy: .newlines)
        var currentSceneIndex = 0
        var currentCharacter = ""
        var collectingDialog = false
        var dialogLines = [String]()
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            if trimmedLine.isEmpty {
                if collectingDialog && !dialogLines.isEmpty {
                    // End of dialog block
                    let dialogText = dialogLines.joined(separator: " ")
                    if currentSceneIndex < scenes.count && !currentCharacter.isEmpty {
                        scenes[currentSceneIndex].addDialog(character: currentCharacter, text: dialogText)
                    }
                    collectingDialog = false
                    dialogLines = []
                    currentCharacter = ""
                }
                continue
            }
            
            // Check if this is a scene heading
            if isSceneHeading(trimmedLine) {
                // End any ongoing dialog collection
                if collectingDialog && !dialogLines.isEmpty {
                    let dialogText = dialogLines.joined(separator: " ")
                    if currentSceneIndex < scenes.count && !currentCharacter.isEmpty {
                        scenes[currentSceneIndex].addDialog(character: currentCharacter, text: dialogText)
                    }
                    collectingDialog = false
                    dialogLines = []
                    currentCharacter = ""
                }
                
                // Find matching scene
                if let index = scenes.firstIndex(where: { $0.heading.contains(trimmedLine) }) {
                    currentSceneIndex = index
                }
                continue
            }
            
            // Check if this is a character name (ALL CAPS)
            if isCharacterName(trimmedLine) {
                // End any ongoing dialog collection
                if collectingDialog && !dialogLines.isEmpty {
                    let dialogText = dialogLines.joined(separator: " ")
                    if currentSceneIndex < scenes.count && !currentCharacter.isEmpty {
                        scenes[currentSceneIndex].addDialog(character: currentCharacter, text: dialogText)
                    }
                }
                
                // Start new dialog collection
                currentCharacter = cleanCharacterName(trimmedLine)
                collectingDialog = true
                dialogLines = []
                continue
            }
            
            // If we're collecting dialog, add this line
            if collectingDialog {
                dialogLines.append(trimmedLine)
            }
        }
        
        // Add any final dialog
        if collectingDialog && !dialogLines.isEmpty {
            let dialogText = dialogLines.joined(separator: " ")
            if currentSceneIndex < scenes.count && !currentCharacter.isEmpty {
                scenes[currentSceneIndex].addDialog(character: currentCharacter, text: dialogText)
            }
        }
    }
    
    // Check if a line is a character name (ALL CAPS)
    private static func isCharacterName(_ line: String) -> Bool {
        // Character names are typically ALL CAPS
        let characterRegex = try? NSRegularExpression(pattern: "^[A-Z][A-Z\\s\\-'().]+$")
        let range = NSRange(location: 0, length: line.utf16.count)
        
        // Check for character name pattern
        if let characterRegex = characterRegex, characterRegex.firstMatch(in: line, options: [], range: range) != nil {
            // Exclude scene headings which might also be in ALL CAPS
            return !isSceneHeading(line)
        }
        
        return false
    }
    
    // Clean character name (remove parentheticals and extensions)
    private static func cleanCharacterName(_ name: String) -> String {
        var cleanName = name
        
        // Remove character extensions (e.g., "(V.O.)", "(O.S.)")
        if let range = name.range(of: "\\(.*?\\)", options: .regularExpression) {
            cleanName = String(name[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return cleanName
    }
}