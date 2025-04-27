import Foundation

class ScreenplayParser {
    static func parseScreenplay(text: String) -> ScreenplaySummary {
        // Split text into lines for processing
        let lines = text.components(separatedBy: .newlines)
        
        // Regex patterns for scene headings - more inclusive patterns
        let traditionalSceneRegex = try? NSRegularExpression(pattern: "^\\s*(?:[0-9]+\\s*)?(?:\"[^\"]+\"\\s*)?(?:FADE\\s+IN:)?\\s*(INT\\.|EXT\\.|INT\\/EXT\\.|I\\/E|INTERIOR|EXTERIOR|INT |EXT )\\s+(.+?)(?:\\s+-\\s+(.+?))?(?:\\s+([0-9\\.]+\\s+[0-9\\.]+))?\\s*$", options: [.caseInsensitive])
        
        // Fallback regex for numbered scenes or other formats
        let numberedSceneRegex = try? NSRegularExpression(pattern: "^\\s*(?:[0-9]+|SCENE|SC\\.?)\\s+(.*)$", options: [.caseInsensitive])
        
        // Handle screenplay scene numbers (like "1", "2") 
        let sceneNumberRegex = try? NSRegularExpression(pattern: "^\\s*([0-9]+)\\s*(.*)$", options: [])
        
        // For extracting location and time from scene headings
        let locationTimeRegex = try? NSRegularExpression(pattern: "^(.+?)(?:\\s+-\\s+|\\s+|\\s*-\\s*|\\s*,\\s*)([A-Z\\s]+(?:DAY|NIGHT|MORNING|EVENING|DUSK|DAWN|AFTERNOON|CONTINUOUS|LATER))$", options: [])
        
        // Time indicators
        let timeIndicators = ["DAY", "NIGHT", "MORNING", "EVENING", "DUSK", "DAWN", "AFTERNOON", "CONTINUOUS", "LATER", "MOMENTS LATER"]
        
        // State tracking
        var currentSceneIndex = -1
        var inDialogue = false
        var currentCharacter = ""
        var dialogueLines = 0
        var dialogueWords = 0
        
        // Results storage
        var scenes: [Scene] = []
        var characters: [String: Character] = [:]
        var currentScene: Scene?
        var sceneDescription = ""
        
        // Process lines to identify scenes and characters
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            if trimmedLine.isEmpty {
                inDialogue = false
                continue
            }
            
            // Various scene heading detection approaches
            var isSceneHeading = false
            var sceneHeadingDetails: (fullHeading: String, location: String, timeOfDay: String, sceneNumber: String?) = 
                (fullHeading: trimmedLine, location: "", timeOfDay: "", sceneNumber: nil)
            
            // Approach 1: Traditional scene heading format
            if let sceneRegex = traditionalSceneRegex,
               let match = sceneRegex.firstMatch(in: trimmedLine, options: [], range: NSRange(location: 0, length: trimmedLine.utf16.count)) {
                
                isSceneHeading = true
                let nsString = trimmedLine as NSString
                sceneHeadingDetails.fullHeading = nsString.substring(with: match.range)
                
                // Safely extract location and time by checking range validity first
                let locAndTime: String
                if match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound {
                    locAndTime = nsString.substring(with: match.range(at: 2))
                } else {
                    locAndTime = ""
                }
                
                // Extract location and time of day
                sceneHeadingDetails.location = locAndTime
                
                if let locTimeRegex = locationTimeRegex,
                   let locTimeMatch = locTimeRegex.firstMatch(in: locAndTime, options: [], range: NSRange(location: 0, length: locAndTime.utf16.count)) {
                    let locTimeNS = locAndTime as NSString
                    if locTimeMatch.numberOfRanges > 1 && locTimeMatch.range(at: 1).location != NSNotFound {
                        sceneHeadingDetails.location = locTimeNS.substring(with: locTimeMatch.range(at: 1))
                    }
                    if locTimeMatch.numberOfRanges > 2 && locTimeMatch.range(at: 2).location != NSNotFound {
                        sceneHeadingDetails.timeOfDay = locTimeNS.substring(with: locTimeMatch.range(at: 2))
                    }
                } else {
                    // Try to extract time indicators manually
                    for indicator in timeIndicators {
                        if locAndTime.contains(indicator) {
                            if let range = locAndTime.range(of: indicator) {
                                let timeStartIndex = range.lowerBound
                                sceneHeadingDetails.timeOfDay = String(locAndTime[timeStartIndex...])
                                sceneHeadingDetails.location = String(locAndTime[..<timeStartIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                                break
                            }
                        }
                    }
                }
                
                // Get scene number if present - checking range validity
                if match.numberOfRanges > 4 && match.range(at: 4).location != NSNotFound {
                    sceneHeadingDetails.sceneNumber = nsString.substring(with: match.range(at: 4))
                }
            }
            // Approach 2: Numbered scene format
            else if let numberedRegex = numberedSceneRegex,
                    let match = numberedRegex.firstMatch(in: trimmedLine, options: [], range: NSRange(location: 0, length: trimmedLine.utf16.count)) {
                
                isSceneHeading = true
                let nsString = trimmedLine as NSString
                sceneHeadingDetails.fullHeading = nsString.substring(with: match.range)
                
                // Safely extract scene number and other parts
                let restOfLine: String
                if match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound {
                    // Check if this is a scene number (digits) or content
                    let part = nsString.substring(with: match.range(at: 1))
                    if let _ = Int(part) {
                        sceneHeadingDetails.sceneNumber = part
                        restOfLine = ""
                    } else {
                        restOfLine = part
                    }
                } else {
                    restOfLine = ""
                }
                
                // Try to extract location and time
                sceneHeadingDetails.location = restOfLine
                
                for indicator in timeIndicators {
                    if restOfLine.contains(indicator) {
                        if let range = restOfLine.range(of: indicator) {
                            let timeStartIndex = range.lowerBound
                            sceneHeadingDetails.timeOfDay = String(restOfLine[timeStartIndex...])
                            sceneHeadingDetails.location = String(restOfLine[..<timeStartIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                            break
                        }
                    }
                }
            }
            // Approach 3: ALL CAPS line that appears to be a scene heading
            else if trimmedLine.uppercased() == trimmedLine && trimmedLine.count > 5 && trimmedLine.count < 100 {
                // Check for scene indicators
                let hasIntExt = trimmedLine.contains("INT") || trimmedLine.contains("EXT") || 
                               trimmedLine.contains("INTERIOR") || trimmedLine.contains("EXTERIOR") ||
                               trimmedLine.contains("I/E") || trimmedLine.contains("INT/EXT")
                
                var hasTimeIndicator = false
                var timeIndicator = ""
                
                for indicator in timeIndicators {
                    if trimmedLine.contains(indicator) {
                        hasTimeIndicator = true
                        timeIndicator = indicator
                        break
                    }
                }
                
                // Check for typical non-scene heading terms
                let isNotTransition = !trimmedLine.contains("CUT TO:") && !trimmedLine.contains("FADE") &&
                                     !trimmedLine.contains("DISSOLVE") && !trimmedLine.contains("SMASH") &&
                                     !trimmedLine.hasSuffix(":") && !trimmedLine.contains("TO:")
                
                if (hasIntExt || hasTimeIndicator) && isNotTransition {
                    isSceneHeading = true
                    sceneHeadingDetails.fullHeading = trimmedLine
                    
                    // Try to extract location and time
                    if hasTimeIndicator {
                        if let range = trimmedLine.range(of: timeIndicator) {
                            let timeStartIndex = range.lowerBound
                            sceneHeadingDetails.timeOfDay = String(trimmedLine[timeStartIndex...])
                            sceneHeadingDetails.location = String(trimmedLine[..<timeStartIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } else {
                        sceneHeadingDetails.location = trimmedLine
                    }
                }
            }
            
            // If we found a scene heading, process it
            if isSceneHeading {
                // If we were building a scene, save it
                if let scene = currentScene {
                    // Trim and clean up scene description
                    scene.description = sceneDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    scenes.append(scene)
                }
                
                // Create new scene
                currentScene = Scene(
                    heading: sceneHeadingDetails.fullHeading,
                    description: "",
                    location: sceneHeadingDetails.location,
                    timeOfDay: sceneHeadingDetails.timeOfDay,
                    sceneNumber: sceneHeadingDetails.sceneNumber
                )
                
                sceneDescription = ""
                currentSceneIndex += 1
                inDialogue = false
                continue
            }
            
            // Check if line is a character name using various detection methods
            let isAllCaps = trimmedLine.uppercased() == trimmedLine && !trimmedLine.isEmpty
            let hasParenthetical = trimmedLine.contains("(") && trimmedLine.contains(")")
            
            // Character name pattern regex - more specific to handle screenplay format
            let characterNameRegex = try? NSRegularExpression(pattern: "^\\s*([A-Z][A-Z\\s']+)(?:\\s*\\([^)]+\\))?\\s*$", options: [])
            let isCharacterName = characterNameRegex?.firstMatch(in: trimmedLine, options: [], range: NSRange(location: 0, length: trimmedLine.utf16.count)) != nil
            
            // More general character detection
            if isAllCaps || isCharacterName || (hasParenthetical && trimmedLine.uppercased().contains(trimmedLine.uppercased().replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression))) {
                // Filter known non-character elements
                let isNotSceneHeading = !trimmedLine.contains("INT") && !trimmedLine.contains("EXT") && 
                                      !trimmedLine.contains("INTERIOR") && !trimmedLine.contains("EXTERIOR")
                let isNotTransition = !trimmedLine.contains("CUT TO") && !trimmedLine.contains("FADE TO") && 
                                    !trimmedLine.contains("DISSOLVE") && !trimmedLine.hasSuffix(":") &&
                                    !trimmedLine.contains("FADE IN") && !trimmedLine.contains("ANGLE")
                let isNotDirection = !trimmedLine.contains("ANGLE ON") && !trimmedLine.contains("CAMERA") &&
                                   !trimmedLine.contains("POV") && !trimmedLine.contains("TITLE") &&
                                   !trimmedLine.contains("INSERT") && !trimmedLine.contains("CLOSE UP")
                
                // Additional filter for camera directions in screenplay
                let isNotCameraDirection = !trimmedLine.hasPrefix("ANGLE") && !trimmedLine.hasPrefix("CAMERA") && 
                                          !trimmedLine.contains("FOLLOW") && !trimmedLine.contains("PAN")
                
                // Character formatting checks
                let isReasonableLength = trimmedLine.count < 50 // Character names aren't very long
                let hasReasonableWords = trimmedLine.components(separatedBy: .whitespaces).count <= 4 // Not too many words
                
                // Check if followed by potential dialogue
                let hasDialogueAfter = index + 1 < lines.count && 
                                       !lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                                       lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines).uppercased() != 
                                       lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                
                if isNotSceneHeading && isNotTransition && isNotDirection && isNotCameraDirection && isReasonableLength && hasReasonableWords && hasDialogueAfter {
                    // Extract character name (remove parentheticals and modifiers)
                    var characterName = trimmedLine
                    
                    // Remove parentheticals like (V.O.) or (O.S.) or (CONT'D)
                    characterName = characterName.replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Remove any non-alphabetic suffixes and common character modifiers
                    characterName = characterName.replacingOccurrences(of: "\\s+CONT'D", with: "", options: .regularExpression)
                    characterName = characterName.replacingOccurrences(of: "\\s+\\(CONT'D\\)", with: "", options: .regularExpression)
                    characterName = characterName.replacingOccurrences(of: "\\s+O\\.S\\.", with: "", options: .regularExpression)
                    characterName = characterName.replacingOccurrences(of: "\\s+\\(O\\.S\\.\\)", with: "", options: .regularExpression)
                    characterName = characterName.replacingOccurrences(of: "\\s+V\\.O\\.", with: "", options: .regularExpression)
                    characterName = characterName.replacingOccurrences(of: "\\s+\\(V\\.O\\.\\)", with: "", options: .regularExpression)
                    
                    // Remove any non-alphabetic characters at the end
                    characterName = characterName.trimmingCharacters(in: CharacterSet.letters.inverted)
                    
                    // Only process if name has substance (length check helps filter false positives)
                    if characterName.count > 1 {
                        // Create or update character
                        if characters[characterName] == nil {
                            characters[characterName] = Character(
                                name: characterName,
                                lineCount: 0,
                                totalWords: 0,
                                firstAppearance: currentSceneIndex
                            )
                        }
                        
                        currentCharacter = characterName
                        inDialogue = true
                        dialogueLines = 0
                        dialogueWords = 0
                        continue
                    }
                }
            }
            
            // Process dialogue
            if inDialogue {
                // Skip parentheticals - more flexible matching to catch both standard and variant formats
                if (trimmedLine.hasPrefix("(") && trimmedLine.hasSuffix(")")) || 
                   (trimmedLine.contains("(") && trimmedLine.contains(")") && trimmedLine.count < 40) {
                    continue
                }
                
                // Count dialogue
                dialogueLines += 1
                dialogueWords += trimmedLine.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
                
                // Check for end of dialogue with more flexible conditions
                let isEndOfDialogue = false
                
                if index + 1 < lines.count {
                    let nextLine = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let isNextLineEmpty = nextLine.isEmpty
                    let isNextLineParenthetical = nextLine.hasPrefix("(") || nextLine.contains("(") && nextLine.contains(")")
                    let isNextLineAllCaps = nextLine.uppercased() == nextLine && !nextLine.isEmpty
                    let isNextLineSceneHeading = nextLine.contains("INT") || nextLine.contains("EXT") || nextLine.contains("SCENE")
                    
                    // More flexible dialogue end detection - end if next line is:
                    // 1. Empty
                    // 2. A parenthetical
                    // 3. ALL CAPS (likely another character or scene heading)
                    // 4. Clearly a scene heading
                    if isNextLineEmpty || isNextLineParenthetical || isNextLineAllCaps || isNextLineSceneHeading {
                        // End of dialogue, update character stats
                        if var character = characters[currentCharacter] {
                            character.lineCount += 1
                            character.totalWords += dialogueWords
                            characters[currentCharacter] = character
                        }
                        inDialogue = false
                    }
                } else {
                    // Last line of the script
                    if var character = characters[currentCharacter] {
                        character.lineCount += 1
                        character.totalWords += dialogueWords
                        characters[currentCharacter] = character
                    }
                    inDialogue = false
                }
            } else if currentScene != nil {
                // Add to current scene description
                sceneDescription += trimmedLine + "\n"
            }
        }
        
        // Add the last scene if we have one
        if let scene = currentScene {
            scene.description = sceneDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            scenes.append(scene)
        }
        
        return ScreenplaySummary(
            sceneCount: scenes.count,
            scenes: scenes,
            characterCount: characters.count,
            characters: characters,
            rawText: text
        )
    }
}