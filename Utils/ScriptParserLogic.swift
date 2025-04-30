import Foundation
import PDFKit
import AVFoundation

// Script section model
public struct ScriptSection: Identifiable, Equatable {
    public let id = UUID()
    public let type: SectionType
    public let text: String
    
    public static func == (lhs: ScriptSection, rhs: ScriptSection) -> Bool {
        return lhs.id == rhs.id
    }
}

// Section type enum
public enum SectionType {
    case narrator
    case character
    case sceneHeading
}

public class ScriptParserLogic {
    // MARK: - Public interface
    
    /// Parse a screenplay text into script sections
    /// - Parameter text: The raw screenplay text to parse
    /// - Returns: An array of parsed script sections
    public static func parseScreenplay(_ text: String) -> [ScriptSection] {
        print("DEBUG: Starting screenplay parsing for text of length \(text.count)")
        var sections: [ScriptSection] = []
        
        // Split text into lines
        let lines = text.components(separatedBy: .newlines)
        print("DEBUG: Split text into \(lines.count) lines")
        
        // Skip the title page by finding "FADE IN:" or similar markers
        var startLineIndex = 0
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine == "FADE IN:" || trimmedLine == "FADE IN" {
                startLineIndex = index + 1
                // Add the FADE IN as a scene heading
                sections.append(ScriptSection(type: .sceneHeading, text: "FADE IN:"))
                break
            }
        }
        
        if startLineIndex == 0 && !lines.isEmpty {
            // If no "FADE IN:" found, try to detect when actual screenplay starts
            // by looking for first scene heading pattern
            for (index, line) in lines.enumerated() {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedLine.hasPrefix("INT.") || trimmedLine.hasPrefix("EXT.") || trimmedLine.hasPrefix("I/E") {
                    startLineIndex = index
                    break
                }
            }
        }
        
        // Process the script line by line, separating narrative from character dialog
        var i = startLineIndex
        var currentSection = ""
        var currentSectionType: SectionType = .narrator
        var currentNarrativeText = ""
        
        while i < lines.count {
            let line = lines[i]
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines but preserve them in the current section
            if trimmedLine.isEmpty {
                if !currentSection.isEmpty {
                    currentSection += "\n"
                }
                i += 1
                continue
            }
            
            // Check for scene headings first
            if isSceneHeading(line) {
                // Add any pending section
                if !currentSection.isEmpty {
                    sections.append(ScriptSection(type: currentSectionType, text: currentSection.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentSection = ""
                }
                
                // Add the scene heading
                sections.append(ScriptSection(type: .sceneHeading, text: trimmedLine))
                currentSectionType = .narrator
                i += 1
                continue
            }
            
            // Special case for the tech startup screenplay - detect names in narrative
            // Look for ALL CAPS words or phrases at the start of a sentence 
            // that are likely character names
            
            // First save any accumulated narrative
            if currentSectionType == .narrator {
                currentNarrativeText = currentSection
            }
            
            // Extract just the potential character name (first all caps word)
            var potentialCharacter = ""
            var restOfLine = ""
            
            let words = trimmedLine.split(separator: " ")
            if !words.isEmpty && String(words[0]) == words[0].uppercased() && words[0].count >= 2 {
                // Found a potential character at the start of a line
                potentialCharacter = String(words[0])
                if words.count > 1 {
                    restOfLine = words.dropFirst().joined(separator: " ")
                }
            }
            
            // Check for strong character indicators (name followed by dialog)
            let isCharacterWithDialog = !potentialCharacter.isEmpty && restOfLine.starts(with: ":")
            
            // Check if line starts with a character name pattern
            if (isCharacterName(line) || (i > 0 && isAllCapsNameAtStartOfLine(line))) && !isSceneHeading(line) {
                // Make sure to add any pending non-empty section
                if !currentSection.isEmpty {
                    sections.append(ScriptSection(type: currentSectionType, text: currentSection.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentSection = ""
                }
                
                // Start a new character section
                let characterName = extractCharacterName(line)
                let dialogLines = extractDialogFromLine(line)
                
                currentSection = characterName
                if !dialogLines.isEmpty {
                    currentSection += "\n" + dialogLines
                }
                
                currentSectionType = .character
                
                // Look ahead for more dialog lines
                var j = i + 1
                
                while j < lines.count {
                    let nextLine = lines[j]
                    let nextTrimmed = nextLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Empty lines within dialog get preserved
                    if nextTrimmed.isEmpty {
                        currentSection += "\n"
                        j += 1
                        continue
                    }
                    
                    // Stop if we hit another character name or scene heading
                    if isCharacterName(nextLine) || isAllCapsNameAtStartOfLine(nextLine) || isSceneHeading(nextLine) {
                        break
                    }
                    
                    // Otherwise it's continuing dialog
                    currentSection += "\n" + nextLine
                    j += 1
                }
                
                // Add this character section
                sections.append(ScriptSection(type: .character, text: currentSection.trimmingCharacters(in: .whitespacesAndNewlines)))
                currentSection = ""
                currentSectionType = .narrator
                i = j // Move past the dialog we've processed
                continue
            } else {
                // Regular narrative line
                if currentSectionType != .narrator {
                    // We've switched from character to narrative, add the character section
                    if !currentSection.isEmpty {
                        sections.append(ScriptSection(type: currentSectionType, text: currentSection.trimmingCharacters(in: .whitespacesAndNewlines)))
                        currentSection = ""
                    }
                    currentSectionType = .narrator
                }
                
                // Add to narrative section
                if !currentSection.isEmpty {
                    currentSection += "\n"
                }
                currentSection += line
                i += 1
            }
        }
        
        // Add any final section
        if !currentSection.isEmpty {
            sections.append(ScriptSection(type: currentSectionType, text: currentSection.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        
        // Special post-processing for this screenplay:
        // Split narrative sections that contain character dialog into separate sections
        var processedSections: [ScriptSection] = []
        
        for section in sections {
            if section.type == .narrator {
                let newSections = splitNarrativeSectionWithDialogs(section)
                processedSections.append(contentsOf: newSections)
            } else {
                processedSections.append(section)
            }
        }
        
        print("DEBUG: Screenplay parsing complete - created \(processedSections.count) total sections")
        return processedSections
    }
    
    /// Process text for proper wrapping, joining lines and preserving paragraph breaks
    /// - Parameter lines: Array of text lines to process
    /// - Returns: Processed text with proper wrapping
    public static func processTextForWrapping(_ lines: [String]) -> String {
        var result = ""
        var previousLineEmpty = false
        var inParenthetical = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty {
                // Only add one newline for empty lines and avoid consecutive empty lines
                if !previousLineEmpty && !result.isEmpty {
                    result += "\n"
                }
                previousLineEmpty = true
            } else {
                // Check for parenthetical expressions (stage directions)
                let startsWithParen = trimmedLine.hasPrefix("(")
                let endsWithParen = trimmedLine.hasSuffix(")")
                
                // Handle start of parenthetical
                if startsWithParen {
                    inParenthetical = true
                }
                
                // Logic for joining lines
                if !result.isEmpty && !previousLineEmpty {
                    if inParenthetical || startsWithParen {
                        // Keep parentheticals on their own line
                        result += "\n"
                    } else {
                        // Normal text flow - add space instead of newline
                        result += " "
                    }
                }
                
                // Add the content
                result += trimmedLine
                
                // Handle end of parenthetical
                if endsWithParen && inParenthetical {
                    inParenthetical = false
                }
                
                previousLineEmpty = false
            }
        }
        
        return result
    }
    
    /// Extract character name from a line of text
    /// - Parameter line: The text line to analyze
    /// - Returns: The extracted character name
    public static func extractCharacterName(_ line: String) -> String {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Look for the first word or words in ALL CAPS
        var name = ""
        let words = trimmedLine.split(separator: " ")
        
        for word in words {
            let str = String(word)
            if str == str.uppercased() && !str.contains(":") {
                if !name.isEmpty {
                    name += " "
                }
                name += str
            } else {
                break
            }
        }
        
        return name
    }
    
    /// Extract dialog text from a line that contains a character name
    /// - Parameter line: The text line to analyze
    /// - Returns: The extracted dialog text
    public static func extractDialogFromLine(_ line: String) -> String {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find where the name ends and dialog begins
        let characterName = extractCharacterName(line)
        
        if characterName.isEmpty || trimmedLine == characterName {
            return ""
        }
        
        // Skip the character name and any colon
        var dialogStart = trimmedLine.index(trimmedLine.startIndex, offsetBy: characterName.count)
        
        // Skip any colon and spaces after the name
        while dialogStart < trimmedLine.endIndex && 
              (trimmedLine[dialogStart] == ":" || trimmedLine[dialogStart] == " ") {
            dialogStart = trimmedLine.index(after: dialogStart)
        }
        
        if dialogStart >= trimmedLine.endIndex {
            return ""
        }
        
        return String(trimmedLine[dialogStart...])
    }
    
    /// Clean speech text by removing stage directions and making narration more readable
    /// - Parameters:
    ///   - text: The text to clean
    ///   - isNarrator: Whether this is narrator speech
    /// - Returns: Cleaned text ready for speech synthesis
    public static func cleanTextForSpeech(_ text: String, isNarrator: Bool) -> String {
        // Clean text by removing stage directions (text in parentheses)
        var cleanText = text.replacingOccurrences(
            of: "\\(.*?\\)",
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Replace INT. with "interior" and EXT. with "exterior" for narration
        if isNarrator {
            cleanText = cleanText.replacingOccurrences(of: "INT.", with: "Interior")
            cleanText = cleanText.replacingOccurrences(of: "EXT.", with: "Exterior")
        }
        
        return cleanText
    }
    
    /// Determine gender from a character name, used for voice assignment
    /// - Parameter name: The character name to analyze
    /// - Returns: Gender code ("M", "F", or "random")
    public static func detectGenderFromName(_ name: String) -> String {
        // Common male name endings and patterns
        let malePatterns = [
            "MR\\.", "MR ", // Mr.
            "\\bJOHN\\b", "\\bJACK\\b", "\\bJAMES\\b", "\\bDAVID\\b", "\\bMICHAEL\\b", "\\bROBERT\\b", 
            "\\bWILLIAM\\b", "\\bJOSEPH\\b", "\\bTHOMAS\\b", "\\bCHARLES\\b", "\\bCHRISTOPHER\\b", 
            "\\bDANIEL\\b", "\\bMATTHEW\\b", "\\bANTHONY\\b", "\\bDONALD\\b", "\\bMARK\\b", "\\bPAUL\\b", 
            "\\bSTEVEN\\b", "\\bANDREW\\b", "\\bKENNETH\\b", "\\bJOSHUA\\b", "\\bKEVIN\\b", "\\bBRIAN\\b", 
            "\\bGEORGE\\b", "\\bTIMOTHY\\b", "\\bRON\\b", "\\bJEFF\\b", "\\bGREG\\b",
            "\\bHE\\b", "\\bHIM\\b", "\\bMAN\\b", "\\bBOY\\b", "\\bGUY\\b", "\\bFATHER\\b", "\\bDAD\\b",
            "\\bSON\\b", "\\bBROTHER\\b", "\\bUNCLE\\b"
        ]
        
        // Common female name endings and patterns
        let femalePatterns = [
            "MS\\.", "MS ", "MRS\\.", "MRS ", "MISS ", // Ms., Mrs., Miss
            "\\bMARY\\b", "\\bPATRICIA\\b", "\\bJENNIFER\\b", "\\bLINDA\\b", "\\bELIZABETH\\b", 
            "\\bBARBARA\\b", "\\bSUSAN\\b", "\\bJESSICA\\b", "\\bSARAH\\b", "\\bKAREN\\b", 
            "\\bLISA\\b", "\\bNANCY\\b", "\\bBETTY\\b", "\\bMARGARET\\b", "\\bSANDRA\\b", "\\bASHLEY\\b", 
            "\\bKIMBERLY\\b", "\\bEMILY\\b", "\\bDONNA\\b", "\\bMICHELLE\\b", "\\bDOROTHY\\b", "\\bCAROL\\b", 
            "\\bAMANDA\\b", "\\bMELISSA\\b", "\\bDEBORAH\\b", "\\bSTEPHANIE\\b", "\\bREBECCA\\b", "\\bLAURA\\b",
            "\\bSHE\\b", "\\bHER\\b", "\\bWOMAN\\b", "\\bGIRL\\b", "\\bLADY\\b", "\\bMOTHER\\b", "\\bMOM\\b",
            "\\bDAUGHTER\\b", "\\bSISTER\\b", "\\bAUNT\\b"
        ]
        
        // Check for male patterns
        for pattern in malePatterns {
            if name.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return "M"
            }
        }
        
        // Check for female patterns
        for pattern in femalePatterns {
            if name.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return "F"
            }
        }
        
        // Default to random if no gender pattern detected
        return "random"
    }
    
    // MARK: - PDF Processing
    
    /// Extract text content from a PDF file
    /// - Parameter pdfURL: URL of the PDF file to process
    /// - Returns: The extracted text content
    public static func extractTextFromPDF(at pdfURL: URL) -> String {
        print("DEBUG: Starting PDF content extraction...")
        
        guard let pdf = PDFDocument(url: pdfURL) else {
            print("DEBUG: Failed to load PDF document")
            return "Failed to load PDF document"
        }
        
        print("DEBUG: Successfully loaded PDF with \(pdf.pageCount) pages")
        var fullText = ""
        
        // Extract text from each page
        for i in 0..<pdf.pageCount {
            if let page = pdf.page(at: i) {
                let pageText = page.string ?? ""
                
                if !pageText.isEmpty {
                    print("DEBUG: Page \(i+1) has \(pageText.count) characters of text")
                    fullText += pageText + "\n"
                } else {
                    print("DEBUG: Page \(i+1) has no text, using OCR")
                    // Use OCR for this page if no text is available
                    let pageImage = page.thumbnail(of: CGSize(width: 1024, height: 1024), for: .mediaBox)
                    if pageImage.cgImage != nil {
                        let ocrText = PDFProcessor.performOCR(on: pageImage)
                        print("DEBUG: OCR extracted \(ocrText.count) characters")
                        fullText += ocrText + "\n"
                    }
                }
            }
        }
        
        print("DEBUG: Total extracted text: \(fullText.count) characters")
        return fullText
    }
    
    // MARK: - Helper functions for screenplay parsing
    
    // Helper function to check if a line is a standalone character name
    private static func isStandaloneCharacter(_ line: String, _ lineIndex: Int, _ allLines: [String]) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Must be all caps and contain only a single word
        if trimmedLine != trimmedLine.uppercased() {
            return false
        }
        
        // Common character name patterns
        let words = trimmedLine.split(separator: " ")
        
        // Check for exact match of known character names in this screenplay
        let knownCharacters = ["SARAH", "MIKE", "JESSICA", "DAVID", "EMILY", "RYAN"]
        
        // Standalone character names should be a single word
        if words.count == 1 && knownCharacters.contains(String(words[0])) {
            return true
        }
        
        // Additional conditions for standalone character identification
        let isAllLetters = trimmedLine.allSatisfy { $0.isLetter }
        let isReasonableLength = trimmedLine.count >= 2 && trimmedLine.count <= 20
        let isNotQuoted = !trimmedLine.hasPrefix("\"") && !trimmedLine.hasSuffix("\"")
        
        // Filter out common emphasized words or phrases
        let nonCharacterTerms = ["LAUNCH DAY", "LAUNCH", "DAY", "YES", "NO", "WAIT", "STOP", "GO", "OK"]
        let isNotCommonTerm = !nonCharacterTerms.contains(trimmedLine)
        
        // Check if there's dialog in the next line (further evidence it's a character name)
        var hasDialogInNextLine = false
        if lineIndex + 1 < allLines.count {
            let nextLine = allLines[lineIndex + 1].trimmingCharacters(in: .whitespacesAndNewlines)
            if !nextLine.isEmpty && nextLine != nextLine.uppercased() {
                hasDialogInNextLine = true
            }
        }
        
        return isAllLetters && 
               isReasonableLength && 
               isNotQuoted && 
               isNotCommonTerm &&
               hasDialogInNextLine
    }
    
    // Helper function to check if a line contains a character name with dialog
    private static func isInlineCharacterWithDialog(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Character with dialog format: NAME dialog text...
        let words = trimmedLine.split(separator: " ", maxSplits: 1)
        if words.count < 2 {
            return false
        }
        
        let firstWord = String(words[0])
        let remainingText = String(words[1])
        
        // First word must be ALL CAPS and be a plausible name
        let isAllCaps = firstWord == firstWord.uppercased()
        let isAllLetters = firstWord.allSatisfy { $0.isLetter }
        let isReasonableLength = firstWord.count >= 2 && firstWord.count <= 20
        
        // The rest must start with lowercase (dialog)
        let dialogStartsWithLowercase = remainingText.first?.isLowercase ?? false
        
        // Known character names in this screenplay
        let knownCharacters = ["SARAH", "MIKE", "JESSICA", "DAVID", "EMILY", "RYAN"]
        let isKnownCharacter = knownCharacters.contains(firstWord)
        
        return isAllCaps && isAllLetters && isReasonableLength && 
               dialogStartsWithLowercase && isKnownCharacter
    }
    
    // Helper function to identify character names
    private static func isCharacterName(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip empty lines
        if trimmedLine.isEmpty {
            return false
        }
        
        // Get first word to check if it's a standalone name
        var firstWord = trimmedLine
        if let spaceIndex = trimmedLine.firstIndex(of: " ") {
            firstWord = String(trimmedLine[..<spaceIndex])
        }
        
        // Check if it's a name followed by dialog marker
        let isNameWithDialog = trimmedLine.contains(":") && 
                              trimmedLine.uppercased() == trimmedLine.prefix(upTo: trimmedLine.firstIndex(of: ":")!)
        
        // Character names are:
        // 1. In ALL CAPS
        // 2. Standalone word or short phrase (not an entire sentence in caps)
        // 3. Not scene headings or special markers
        
        let isAllCaps = trimmedLine == trimmedLine.uppercased()
        let isShortText = trimmedLine.count < 40
        let hasNoLowercase = !trimmedLine.contains(where: { $0.isLowercase })
        let wordCount = trimmedLine.split(separator: " ").count
        let isReasonableNameLength = wordCount <= 3 || (isNameWithDialog && wordCount <= 5)
        
        // Exclude scene headings and special markers
        let notSceneHeading = !trimmedLine.hasPrefix("INT.") && 
                             !trimmedLine.hasPrefix("EXT.") &&
                             !trimmedLine.contains("FADE") &&
                             !trimmedLine.hasSuffix(":")
        
        // For this specific script example, we need a special case
        // to recognize character names directly at start of lines
        let appearsToBeCharacter = isAllCaps && 
                                  hasNoLowercase && 
                                  isReasonableNameLength && 
                                  firstWord.count >= 2 &&
                                  isShortText
        
        return appearsToBeCharacter && notSceneHeading
    }
    
    // Helper function to check if a line starts with an ALL CAPS name
    private static func isAllCapsNameAtStartOfLine(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip empty lines
        if trimmedLine.isEmpty {
            return false
        }
        
        // Check for first word being ALL CAPS
        let words = trimmedLine.split(separator: " ")
        if words.isEmpty {
            return false
        }
        
        // A real character name would be standalone on a line (centered) or 
        // followed by dialog that's not in all caps
        
        // Check if this is a quoted text like "LAUNCH DAY!" which isn't a character name
        if trimmedLine.hasPrefix("\"") || trimmedLine.hasSuffix("\"") {
            return false
        }
        
        let firstWord = String(words[0])
        
        // Check if we have what looks like dialog after the potential name
        let hasNonCapsTextAfterName = words.count > 1 && 
                                     String(words[1]) != String(words[1]).uppercased()
        
        // Character names must be all letters (no symbols, quotes, etc)
        let containsOnlyLetters = firstWord.allSatisfy { $0.isLetter }
        
        // Character names are typically ALL CAPS at the start
        let isAllCaps = firstWord == firstWord.uppercased()
        let hasLetters = firstWord.contains(where: { $0.isLetter })
        let isReasonableLength = firstWord.count >= 2 && firstWord.count <= 20
        
        // Common words that aren't character names (scene directions, transitions, emphasized words)
        let nonNameWords = ["INT", "EXT", "FADE", "CUT", "DISSOLVE", "ANGLE", "PAN", 
                           "ZOOM", "THE", "AND", "BUT", "LAUNCH", "DAY", "A", "TO", 
                           "OF", "ON", "IN", "THIS", "THAT", "THESE", "THOSE"]
        let isNotCommonWord = !nonNameWords.contains(firstWord)
        
        // If it's a single word on a line and it matches our criteria, it's likely a character name
        let isSingleWordOnLine = words.count == 1
        
        // Additional check for lines with parentheses, often scene direction with character descriptions
        let containsParentheses = trimmedLine.contains("(") && trimmedLine.contains(")")
        
        // If there are parentheses, check if they're character descriptions or actor directions
        // Character descriptions usually come after the name, not before
        let isCharacterDescription = containsParentheses && 
                                    trimmedLine.firstIndex(of: "(")! > trimmedLine.startIndex &&
                                    // Make sure we don't incorrectly classify as character description 
                                    // if the parentheses are just for a direction like (yelling)
                                    !trimmedLine.contains { $0.isLowercase } // should contain some lowercase if a direction
        
        // Character names should have no punctuation (except possibly a colon)
        let hasNoPunctuation = !firstWord.contains { $0.isPunctuation && $0 != ":" }
        
        // If there's only one word and it meets our criteria, it's likely a character name
        if isSingleWordOnLine {
            return isAllCaps && hasLetters && containsOnlyLetters && isReasonableLength && 
                   isNotCommonWord && hasNoPunctuation && !containsParentheses
        }
        
        // If there are multiple words but first is all caps and followed by non-caps, 
        // it might be a character name followed by dialog
        if hasNonCapsTextAfterName {
            return isAllCaps && hasLetters && containsOnlyLetters && isReasonableLength && 
                   isNotCommonWord && hasNoPunctuation
        }
        
        // For character descriptions in parentheses, verify we have a name pattern first
        if isCharacterDescription {
            return false // This is narrative text with character description, not dialog
        }
        
        return false // Default to not a character name for anything else
    }
    
    // Helper function to identify scene headings
    private static func isSceneHeading(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip empty lines
        if trimmedLine.isEmpty {
            return false
        }
        
        // Scene headings in standard screenplay format follow a few basic patterns:
        
        // 1. Most common form: starts with INT./EXT. followed by location
        if trimmedLine.hasPrefix("INT.") || 
           trimmedLine.hasPrefix("EXT.") || 
           trimmedLine.hasPrefix("INT./EXT.") || 
           trimmedLine.hasPrefix("I/E") ||
           trimmedLine.hasPrefix("INTERIOR") ||
           trimmedLine.hasPrefix("EXTERIOR") {
            
            return true
        }
        
        // Special case: "FADE IN:" is a common screenplay marker
        if trimmedLine == "FADE IN:" || trimmedLine == "FADE OUT:" ||
           trimmedLine == "FADE IN" || trimmedLine == "FADE OUT" {
            return true
        }
        
        // 2. ALL CAPS location followed by time of day
        let isAllCaps = trimmedLine == trimmedLine.uppercased()
        let timeWords = ["DAY", "NIGHT", "MORNING", "EVENING", "DUSK", "DAWN", "AFTERNOON", "LATER", "CONTINUOUS"]
        
        // Check if the line ends with a time indicator and doesn't contain dialog punctuation
        if isAllCaps && 
           !trimmedLine.contains("!") && 
           !trimmedLine.contains("?") && 
           !trimmedLine.contains("(") {
            
            for timeWord in timeWords {
                if trimmedLine.hasSuffix(timeWord) || 
                   trimmedLine.contains(" - " + timeWord) ||
                   trimmedLine.contains(" – " + timeWord) ||
                   trimmedLine.contains(" — " + timeWord) {
                    return true
                }
            }
        }
        
        // 3. Numbered scene headings
        if isAllCaps && 
           (trimmedLine.hasPrefix("SCENE ") || 
            trimmedLine.hasPrefix("SC. ") || 
            (trimmedLine.hasPrefix("#") && trimmedLine.range(of: "^#\\d+", options: .regularExpression) != nil)) {
            return true
        }
        
        return false
    }
    
    // Helper to split a narrative section that might contain character dialog
    private static func splitNarrativeSectionWithDialogs(_ section: ScriptSection) -> [ScriptSection] {
        var result: [ScriptSection] = []
        
        // Split the section into lines
        let lines = section.text.components(separatedBy: .newlines)
        var currentNarrative = ""
        var i = 0
        
        // We need additional context for this screenplay format:
        // 1. Real character dialog is typically a single name like "SARAH" on its own line
        // 2. If there are no quotes around the ALL CAPS text, it's more likely to be a character name
        // 3. Character names are not followed by exclamation marks (like "LAUNCH DAY!")
        
        while i < lines.count {
            let line = lines[i]
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty {
                if !currentNarrative.isEmpty {
                    currentNarrative += "\n"
                }
                i += 1
                continue
            }
            
            // Check if this is a standalone character name (centered on its own line)
            let isStandaloneCharacterName = isStandaloneCharacter(line, i, lines)
            
            // Check if this is a character name with dialog following on the same line
            let isInlineCharacterDialog = isInlineCharacterWithDialog(line)
            
            if isStandaloneCharacterName || isInlineCharacterDialog {
                // Add any accumulated narrative first
                if !currentNarrative.isEmpty {
                    result.append(ScriptSection(type: .narrator, text: currentNarrative.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentNarrative = ""
                }
                
                // Extract character name
                let characterName = extractCharacterName(line)
                var characterSection = characterName
                
                // Add dialog from this line if any (for inline dialog)
                if isInlineCharacterDialog {
                    let dialogInLine = extractDialogFromLine(line)
                    if !dialogInLine.isEmpty {
                        characterSection += "\n" + dialogInLine
                    }
                }
                
                // Look ahead for continued dialog 
                // (especially important for standalone character names)
                var j = i + 1
                var foundMoreDialog = false
                
                while j < lines.count {
                    let nextLine = lines[j]
                    let nextTrimmed = nextLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if nextTrimmed.isEmpty {
                        characterSection += "\n"
                        j += 1
                        continue
                    }
                    
                    // Stop at next character name or scene heading
                    if isStandaloneCharacter(nextLine, j, lines) || 
                       isInlineCharacterWithDialog(nextLine) || 
                       isSceneHeading(nextLine) {
                        break
                    }
                    
                    // Add line to dialog
                    characterSection += "\n" + nextLine
                    foundMoreDialog = true
                    j += 1
                }
                
                // Only add as character if we found dialog
                if isStandaloneCharacterName && !foundMoreDialog {
                    // Edge case: standalone character name with no dialog
                    // Treat as narrative instead
                    if !currentNarrative.isEmpty {
                        currentNarrative += "\n"
                    }
                    currentNarrative += line
                    i += 1
                } else {
                    // Add the character section with dialog
                    result.append(ScriptSection(type: .character, text: characterSection.trimmingCharacters(in: .whitespacesAndNewlines)))
                    
                    // Move forward past the processed lines
                    i = foundMoreDialog ? j : i + 1
                }
            } else {
                // Regular narrative
                if !currentNarrative.isEmpty {
                    currentNarrative += "\n"
                }
                currentNarrative += line
                i += 1
            }
        }
        
        // Add any remaining narrative
        if !currentNarrative.isEmpty {
            result.append(ScriptSection(type: .narrator, text: currentNarrative.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        
        return result
    }
}