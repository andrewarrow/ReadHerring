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
                    
                    // Stop if we hit another character cue, a scene heading, or an
                    // action line that starts with an ALL-CAPS name followed by
                    // lowercase narrative (e.g. "MIKE (20s, engineer) rushes in …").
                    if isCharacterName(nextLine) ||
                       isAllCapsNameAtStartOfLine(nextLine) ||
                       isSceneHeading(nextLine) ||
                       startsWithCapsNameAndNarrative(nextLine) {
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
        // Join lines until we hit a blank line – that indicates a new paragraph.
        // Preserve blank‐line paragraph breaks so that the UI can render them with
        // an extra line feed.  We purposely avoid any language analysis here
        // (see tasks/1.txt) and rely purely on structural cues (blank lines).

        var wrappedParagraphs: [String] = []
        var currentParagraph = ""

        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            // Blank line → paragraph break
            if trimmed.isEmpty {
                if !currentParagraph.isEmpty {
                    wrappedParagraphs.append(currentParagraph)
                    currentParagraph = ""
                }
                continue
            }

            if currentParagraph.isEmpty {
                currentParagraph = trimmed
            } else {
                currentParagraph += " " + trimmed
            }
        }

        if !currentParagraph.isEmpty {
            wrappedParagraphs.append(currentParagraph)
        }

        // Use a double newline to separate paragraphs so SwiftUI Text preserves
        // the break after we later call .fixedSize().
        return wrappedParagraphs.joined(separator: "\n\n")
    }
    
    /// Extract character name from a line of text
    /// - Parameter line: The text line to analyze
    /// - Returns: The extracted character name
    public static func extractCharacterName(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // If the name is followed by a colon we treat everything before the colon
        // as the character name (e.g. "JOHNNY: Hey there!").
        if let colonRange = trimmed.range(of: ":") {
            return String(trimmed[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        // Remove any parenthetical description – those frequently follow the
        // name on the same line (e.g. "SARAH (O.S.)").
        let withoutParenthetical = trimmed.components(separatedBy: "(").first ?? trimmed

        // Return the remaining ALL-CAPS portion as the name.
        return withoutParenthetical.trimmingCharacters(in: .whitespaces)
    }
    
    /// Extract dialog text from a line that contains a character name
    /// - Parameter line: The text line to analyze
    /// - Returns: The extracted dialog text
    public static func extractDialogFromLine(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let colonRange = trimmed.range(of: ":") else {
            return "" // No in-line dialogue.
        }

        let afterColon = trimmed[colonRange.upperBound...]
        return afterColon.trimmingCharacters(in: .whitespaces)
    }
    
    /// Clean speech text by removing stage directions and making narration more readable
    /// - Parameters:
    ///   - text: The text to clean
    ///   - isNarrator: Whether this is narrator speech
    /// - Returns: Cleaned text ready for speech synthesis
    public static func cleanTextForSpeech(_ text: String, isNarrator: Bool) -> String {
        var cleaned = text

        // Collapse newlines into single spaces so the synthesiser flows better.
        cleaned = cleaned.replacingOccurrences(of: "\n", with: " ")

        // Remove duplicated whitespace.
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }

        // For narrator we strip stage directions (parenthetical/bracketed text).
        if isNarrator {
            let patterns = ["\\(.*?\\)", "\\[.*?\\]"]
            for pattern in patterns {
                cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            }
        }

        // Trim once more.
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Determine gender from a character name, used for voice assignment
    /// - Parameter name: The character name to analyze
    /// - Returns: Gender code ("M", "F", or "random")
    public static func detectGenderFromName(_ name: String) -> String {
        // Very lightweight heuristics – we purposefully avoid any heavy
        // NLP and instead just look for common masculine/feminine cues in the
        // name itself.  If we cannot decide we return "random" so callers can
        // pick any voice.

        let upper = name.uppercased()

        // Obvious keywords first.
        let femaleKeywords = ["MOM", "MOTHER", "WOMAN", "GIRL", "LADY", "SISTER", "QUEEN"]
        let maleKeywords   = ["DAD", "FATHER", "MAN", "BOY", "GUY", "BROTHER", "KING"]

        if femaleKeywords.contains(where: { upper.contains($0) }) {
            return "F"
        }
        if maleKeywords.contains(where: { upper.contains($0) }) {
            return "M"
        }

        // Simple suffix based guess – far from perfect but better than nothing.
        let feminineSuffixes = ["A", "E", "I"]
        if let last = upper.last, feminineSuffixes.contains(String(last)) {
            return "F"
        }

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

    /// Checks if a line should be treated as a character cue (ALL CAPS, short, no punctuation that would
    /// indicate a scene heading or transition).
    private static func isCharacterName(_ line: String) -> Bool {
        // Determines if the ENTIRE line is meant to be a character cue. A cue is
        // typically ALL CAPS (optionally followed by a parenthetical such as
        // "(CONT'D)") and nothing else.

        var trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }

        // Strip any trailing parenthetical so we can evaluate the core name.
        if let parenStart = trimmed.firstIndex(of: "("), trimmed.last == ")" {
            trimmed = String(trimmed[..<parenStart])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Reject obvious non-cues.
        if isSceneHeading(trimmed) { return false }
        let transitionKeywords = ["FADE", "CUT TO", "DISSOLVE"]
        if transitionKeywords.contains(where: { trimmed.contains($0) }) {
            return false
        }

        // Must be all caps (no lowercase letters).
        let hasLowercase = trimmed.rangeOfCharacter(from: CharacterSet.lowercaseLetters) != nil
        if hasLowercase { return false }

        // Must be reasonably short and contain at most a few words.
        if trimmed.count > 40 { return false }
        if trimmed.split(separator: " ").count > 4 { return false }

        // Should not contain a period unless it is an abbreviation like O.S. or V.O.
        // We'll allow periods as long as every token is <=3 chars (heuristic).
        let tokens = trimmed.split(separator: " ")
        let invalidPeriod = tokens.contains { $0.contains(".") && $0.count > 4 }
        if invalidPeriod { return false }

        return true
    }

    /// Checks if the first token on the line is ALL CAPS – used to detect compact formats like
    /// "JOHN: Hey there" where the line contains both cue and dialogue.
    private static func isAllCapsNameAtStartOfLine(_ line: String) -> Bool {
        // Looks for compact inline dialogue like "SARAH: We'll ship tomorrow.".
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let colonIdx = trimmed.firstIndex(of: ":") else { return false }
        let namePart = String(trimmed[..<colonIdx])

        // Reject obvious headings.
        if namePart.hasPrefix("INT") || namePart.hasPrefix("EXT") { return false }

        let isAllCaps = namePart == namePart.uppercased()
        if !isAllCaps { return false }

        if namePart.count > 40 { return false }

        return true
    }

    /// Basic scene-heading detection purely from structural conventions (all caps INT./EXT. etc.).
    private static func isSceneHeading(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }

        // The vast majority of scene headings start with INT./EXT./I/E
        let prefixes = ["INT.", "EXT.", "INT/EXT", "EXT/INT", "I/E", "INT ", "EXT "]
        for p in prefixes {
            if trimmed.uppercased().hasPrefix(p) { return true }
        }

        return false
    }

    /// Detects a line that starts with an ALL-CAPS token followed by narrative
    /// text (lower-case letters) – used to terminate the previous character’s
    /// dialogue block.
    private static func startsWithCapsNameAndNarrative(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstSpace = trimmed.firstIndex(of: " ") else { return false }
        let firstToken = String(trimmed[..<firstSpace])

        // Ensure the first token is all caps and not a scene heading.
        guard !firstToken.isEmpty,
              firstToken == firstToken.uppercased(),
              !firstToken.hasPrefix("INT"),
              !firstToken.hasPrefix("EXT") else { return false }

        // Check for lowercase letters in remainder.
        let remainder = trimmed[firstSpace...]
        return remainder.rangeOfCharacter(from: CharacterSet.lowercaseLetters) != nil
    }

    /// Splits a narrative section that embeds character-dialogue shortcuts (e.g. "JOHN: Sure.  SARAH: Hi!")
    /// into separate character sections.  If no embedded cues are detected the original section is returned.
    private static func splitNarrativeSectionWithDialogs(_ section: ScriptSection) -> [ScriptSection] {
        var results: [ScriptSection] = []

        // We look for "NAME: dialog" patterns.  Split the line accordingly.
        let pattern = "([A-Z0-9 \\']{2,40}):\\s*([^\\n]+)" // very loose, stop at newline
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [section]
        }

        let nsText = section.text as NSString
        let matches = regex.matches(in: section.text, options: [], range: NSRange(location: 0, length: nsText.length))
        if matches.isEmpty {
            // No inline dialog patterns – keep as is.
            return [section]
        }

        var lastIndex = 0
        for match in matches {
            // Add any preceding narrative as its own section.
            if match.range.location > lastIndex {
                let narrativeRange = NSRange(location: lastIndex, length: match.range.location - lastIndex)
                let narrative = nsText.substring(with: narrativeRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if !narrative.isEmpty {
                    results.append(ScriptSection(type: .narrator, text: narrative))
                }
            }

            // Character name and dialog
            if match.numberOfRanges >= 3 {
                let name = nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                let dialog = nsText.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                let combined = name + "\n" + dialog
                results.append(ScriptSection(type: .character, text: combined))
            }

            lastIndex = match.range.location + match.range.length
        }

        // Append any trailing narrative
        if lastIndex < nsText.length {
            let tailRange = NSRange(location: lastIndex, length: nsText.length - lastIndex)
            let tail = nsText.substring(with: tailRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty {
                results.append(ScriptSection(type: .narrator, text: tail))
            }
        }

        return results.isEmpty ? [section] : results
    }
}
