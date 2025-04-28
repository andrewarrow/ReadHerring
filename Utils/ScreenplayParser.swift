import Foundation

class ScreenplayParser {
    
    // Special narrator name to use for non-dialog content
    static let narratorName = "NARRATOR"
    
    static func parseScreenplay(text: String) -> ScreenplaySummary {
        print("DEBUG: Starting screenplay parsing")
        print("DEBUG: Text length: \(text.count) characters")
        
        // Split text into lines for processing
        let lines = text.components(separatedBy: .newlines)
        print("DEBUG: Split into \(lines.count) lines")
        
        // Regex patterns for scene headings
        let sceneHeadingRegex = try? NSRegularExpression(pattern: "^\\s*(INT\\.|EXT\\.|INT\\/EXT\\.|I\\/E|INTERIOR|EXTERIOR|INT |EXT )\\s+(.+?)(?:\\s+-\\s+(.+?))?\\s*$", options: [.caseInsensitive])
        
        // For character names - simpler pattern focusing on ALL CAPS format
        let characterRegex = try? NSRegularExpression(pattern: "^\\s*([A-Z][A-Z\\s'\\(\\)-\\.]+)\\s*$")
        
        // State tracking
        var scenes: [Scene] = []
        var characters: [String: Character] = [:]
        var currentScene: Scene?
        
        // Parse the title and credits block first (before the first scene heading)
        var titleAndCredits = ""
        var titleCollecting = true
        
        print("DEBUG: Starting first pass analysis")
        
        // First pass to identify the screenplay structure
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            if line.isEmpty {
                i += 1
                continue
            }
            
            print("DEBUG: Processing line \(i): \(line.prefix(40))...")
            
            // Is this a scene heading?
            let isSceneHeading = sceneHeadingRegex?.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) != nil ||
                                 (line.uppercased() == line && (line.contains("INT") || line.contains("EXT")) && 
                                  !line.contains("CUT TO") && !line.contains("FADE TO") && !line.hasSuffix(":"))
            
            if isSceneHeading {
                print("DEBUG: Found scene heading: \(line)")
                
                // If we've found a scene heading, stop collecting title credits
                if titleCollecting {
                    print("DEBUG: Ending title collection. Collected: \(titleAndCredits.count) chars")
                    titleCollecting = false
                }
                
                // Extract location and time of day
                var location = ""
                var timeOfDay = ""
                
                if let regex = sceneHeadingRegex,
                   let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) {
                    let nsLine = line as NSString
                    if match.range(at: 2).location != NSNotFound {
                        location = nsLine.substring(with: match.range(at: 2))
                    }
                    if match.range(at: 3).location != NSNotFound {
                        timeOfDay = nsLine.substring(with: match.range(at: 3))
                    }
                }
                
                // End previous scene if there was one
                if let scene = currentScene {
                    print("DEBUG: Ending previous scene. Description length: \(scene.description.count)")
                    scenes.append(scene)
                    print("DEBUG: Now have \(scenes.count) scenes")
                }
                
                // Start a new scene
                currentScene = Scene(
                    heading: line,
                    description: "",
                    location: location,
                    timeOfDay: timeOfDay
                )
                print("DEBUG: Started new scene with heading: \(line)")
                
                // Skip to the next line
                i += 1
                continue
            }
            
            // If still collecting title credits and not yet at a scene
            if titleCollecting && currentScene == nil {
                print("DEBUG: Adding to title: \(line.prefix(40))...")
                titleAndCredits += line + "\n"
                i += 1
                continue
            }
            
            // If we've found a scene heading by now, we should have a current scene
            if let scene = currentScene {
                // Is this a character name? (All caps, not scene heading or transition)
                let isCharacterName = characterRegex?.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) != nil &&
                                     !line.contains("CUT TO") && !line.contains("FADE") && !line.hasSuffix(":") &&
                                     !line.contains("INT") && !line.contains("EXT") && line.count < 40
                
                if isCharacterName {
                    print("DEBUG: Found character name: \(line)")
                    
                    // Extract the character name (remove any parentheticals)
                    var characterName = line.replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)
                                          .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    print("DEBUG: Cleaned character name: \(characterName)")
                    
                    // Record the character
                    if characters[characterName] == nil {
                        print("DEBUG: New character detected: \(characterName)")
                        characters[characterName] = Character(
                            name: characterName,
                            lineCount: 0,
                            totalWords: 0,
                            firstAppearance: scenes.count
                        )
                    }
                    
                    // Collect the dialogue text
                    var dialogueText = ""
                    var j = i + 1
                    
                    // Collect lines until we hit an empty line, another character, or scene heading
                    while j < lines.count {
                        let dialogLine = lines[j].trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Stop if empty line
                        if dialogLine.isEmpty {
                            print("DEBUG: Ending dialog at empty line")
                            break
                        }
                        
                        // Check if this is a new character or scene heading
                        let isNewCharacter = characterRegex?.firstMatch(in: dialogLine, range: NSRange(location: 0, length: dialogLine.utf16.count)) != nil
                        let isNewScene = sceneHeadingRegex?.firstMatch(in: dialogLine, range: NSRange(location: 0, length: dialogLine.utf16.count)) != nil
                        
                        if isNewCharacter || isNewScene {
                            print("DEBUG: Ending dialog: found new \(isNewCharacter ? "character" : "scene")")
                            break
                        }
                        
                        // Add to dialogue, preserving parentheticals
                        dialogueText += dialogLine + " "
                        j += 1
                    }
                    
                    print("DEBUG: Collected dialog: \(dialogueText.prefix(40))...")
                    
                    // Add the dialogue to the scene
                    scene.addDialog(character: characterName, text: dialogueText.trimmingCharacters(in: .whitespacesAndNewlines))
                    print("DEBUG: Added dialog to scene. Scene now has \(scene.dialogs.count) dialog items")
                    
                    // Update character statistics
                    var character = characters[characterName]!
                    character.lineCount += 1
                    character.totalWords += dialogueText.split(separator: " ").count
                    characters[characterName] = character
                    
                    // Skip past the dialogue we've processed
                    i = j
                } else {
                    // This is scene description/action text
                    print("DEBUG: Processing as scene description: \(line.prefix(40))...")
                    
                    // Check if the next line contains a character name before adding to description
                    var isPartOfDescription = true
                    
                    if i + 1 < lines.count {
                        let nextLine = lines[i + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                        let isNextLineCharacter = characterRegex?.firstMatch(in: nextLine, range: NSRange(location: 0, length: nextLine.utf16.count)) != nil
                        
                        if isNextLineCharacter && !line.isEmpty {
                            // This could be a character introduction
                            print("DEBUG: Found character intro before dialog: \(line.prefix(40))...")
                            
                            // Add it as separate narrator dialog
                            scene.addDialog(character: narratorName, text: line)
                            print("DEBUG: Added narrator dialog. Scene now has \(scene.dialogs.count) dialog items")
                            isPartOfDescription = false
                        }
                    }
                    
                    // If still part of the scene description, add it
                    if isPartOfDescription {
                        print("DEBUG: Adding to scene description")
                        scene.description += line + "\n"
                    }
                    
                    i += 1
                }
            } else {
                // No current scene yet, but not a scene heading - skip
                print("DEBUG: No current scene, skipping line")
                i += 1
            }
        }
        
        // Add the final scene if exists
        if let scene = currentScene {
            print("DEBUG: Adding final scene. Description length: \(scene.description.count)")
            scenes.append(scene)
            print("DEBUG: Final scene count: \(scenes.count)")
        }
        
        // If we have title/credits and scenes, add title to first scene
        if !titleAndCredits.isEmpty && !scenes.isEmpty {
            let titleScene = scenes[0]
            let titleText = titleAndCredits.trimmingCharacters(in: .whitespacesAndNewlines)
            print("DEBUG: Adding title/credits as narrator dialog: \(titleText.prefix(100))...")
            
            // Insert title at the beginning of dialogs list
            titleScene.dialogs.insert(Scene.Dialog(character: narratorName, text: titleText), at: 0)
            print("DEBUG: First scene now has \(titleScene.dialogs.count) dialog items")
        }
        
        print("DEBUG: Starting scene dialog processing")
        // Create a properly sequential list of dialogs for each scene
        processSceneDialogs(scenes: scenes)
        
        print("DEBUG: Screenplay parsing complete. Scenes: \(scenes.count), Characters: \(characters.count)")
        return ScreenplaySummary(
            sceneCount: scenes.count,
            scenes: scenes,
            characterCount: characters.count,
            characters: characters,
            rawText: text
        )
    }
    
    // Process scene dialogs to ensure proper reading sequence
    private static func processSceneDialogs(scenes: [Scene]) {
        for (sceneIndex, scene) in scenes.enumerated() {
            print("DEBUG: Processing dialogs for scene \(sceneIndex + 1) of \(scenes.count)")
            print("DEBUG: Scene heading: \(scene.heading)")
            print("DEBUG: Scene description length: \(scene.description.count) chars")
            print("DEBUG: Scene has \(scene.dialogs.count) original dialog items")
            
            var sequentialDialogs: [Scene.Dialog] = []
            
            // First, check if title/credits appear as dialog 0 (should be preserved)
            var startIndex = 0
            if sceneIndex == 0 && !scene.dialogs.isEmpty && scene.dialogs[0].character == narratorName {
                if scene.dialogs[0].text.contains("MELTDOWN") || scene.dialogs[0].text.contains("FADE IN") {
                    // Keep the title as first dialog
                    sequentialDialogs.append(scene.dialogs[0])
                    startIndex = 1
                    print("DEBUG: Preserved title/credits as first dialog")
                }
            }
            
            // Second, add scene heading as a narrator dialog
            if !scene.heading.isEmpty {
                print("DEBUG: Adding scene heading as narrator dialog")
                sequentialDialogs.append(Scene.Dialog(character: narratorName, text: scene.heading))
            }
            
            // Third, combine all narrator descriptions into a single block
            // instead of having them split into multiple sections
            var combinedDescription = scene.description.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Find any additional narrator descriptions that should be combined
            for dialog in scene.dialogs {
                if dialog.character == narratorName && 
                   !dialog.text.contains("FADE IN") && 
                   !dialog.text.contains("MELTDOWN") &&
                   dialog.text != scene.heading &&
                   !dialog.text.contains("INT.") &&
                   !dialog.text.contains("EXT.") {
                    
                    // Check if this is a standalone character description
                    if dialog.text.contains(")") && dialog.text.count < 100 {
                        // This is likely a short character description, keep it separate
                        continue
                    }
                    
                    // Add to the combined description
                    if !combinedDescription.isEmpty {
                        combinedDescription += " "
                    }
                    combinedDescription += dialog.text
                }
            }
            
            // Add the combined description if not empty
            if !combinedDescription.isEmpty {
                print("DEBUG: Adding combined scene description: \(combinedDescription.prefix(50))...")
                sequentialDialogs.append(Scene.Dialog(character: narratorName, text: combinedDescription))
            }
            
            // Finally, add character dialogs, but clean up any that include narration
            for dialogIndex in startIndex..<scene.dialogs.count {
                let dialog = scene.dialogs[dialogIndex]
                
                // Skip narrator dialogs already handled
                if dialog.character == narratorName &&
                   (dialog.text == scene.heading || 
                    combinedDescription.contains(dialog.text) ||
                    dialog.text.contains("FADE IN") ||
                    dialog.text.contains("MELTDOWN")) {
                    continue
                }
                
                // Fix character dialog that might include descriptions of the next character
                if dialog.character != narratorName {
                    var dialogText = dialog.text
                    
                    // Look for character descriptions - pattern: NAME (description)
                    if let range = dialogText.range(of: "\\s+[A-Z]{2,}\\s*\\([^\\)]+\\)", options: .regularExpression) {
                        // Split the dialog at this point
                        let characterDialog = String(dialogText[..<range.lowerBound])
                        let nextCharacterDesc = String(dialogText[range.lowerBound...])
                        
                        // Add the clean character dialog
                        sequentialDialogs.append(Scene.Dialog(
                            character: dialog.character,
                            text: characterDialog.trimmingCharacters(in: .whitespacesAndNewlines)
                        ))
                        
                        // Add the character description as narrator text
                        sequentialDialogs.append(Scene.Dialog(
                            character: narratorName,
                            text: nextCharacterDesc.trimmingCharacters(in: .whitespacesAndNewlines)
                        ))
                        
                        continue
                    }
                }
                
                // Add the dialog unchanged if no special processing needed
                sequentialDialogs.append(dialog)
            }
            
            // Replace the scene's dialogs with our properly sequenced list
            scene.dialogs = sequentialDialogs
            print("DEBUG: Scene now has \(scene.dialogs.count) sequential dialog items")
            
            // Print the first few dialogs for debugging
            for (i, dialog) in scene.dialogs.prefix(min(3, scene.dialogs.count)).enumerated() {
                print("DEBUG: Dialog \(i): Character: \(dialog.character), Text: \(dialog.text.prefix(50))...")
            }
        }
    }
    
    // Helper method to check if a line is a scene heading
    static func checkIfSceneHeading(_ line: String) -> Bool {
        let patterns = ["^INT\\.", "^EXT\\.", "^INT/EXT\\.", "^I/E\\.", "^INTERIOR", "^EXTERIOR"]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: line.utf16.count)
                if regex.firstMatch(in: line, options: [], range: range) != nil {
                    return true
                }
            }
        }
        return false
    }
}