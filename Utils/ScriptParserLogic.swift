import Foundation
import PDFKit
import AVFoundation
import Vision // <-- Add Vision import
import UIKit // <-- Add UIKit for UIImage/CGRect

// --- Data Structures for Vision Results ---

// Represents a single block of text recognized by Vision
struct TextBlock: Identifiable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect // Coordinates relative to the page image
    let confidence: Float
}

// Represents a line of text, potentially composed of multiple TextBlocks
struct TextLine: Identifiable {
    let id = UUID()
    var blocks: [TextBlock] = []
    var boundingBox: CGRect {
        guard !blocks.isEmpty else { return .zero }
        // Calculate the union of all block boxes in the line
        return blocks.reduce(blocks[0].boundingBox) { $0.union($1.boundingBox) }
    }
    var text: String {
        // Sort blocks horizontally before joining
        blocks.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
              .map { $0.text }
              .joined(separator: " ")
    }
}

// Represents a paragraph, composed of multiple TextLines
struct Paragraph: Identifiable {
    let id = UUID()
    var lines: [TextLine] = []
    var boundingBox: CGRect {
        guard !lines.isEmpty else { return .zero }
        // Calculate the union of all line boxes in the paragraph
        return lines.reduce(lines[0].boundingBox) { $0.union($1.boundingBox) }
    }
    var text: String {
        lines.map { $0.text }.joined(separator: "\n")
    }
}


// --- Original Script Section Model ---
// Note: This might need to be replaced or adapted based on the output of processExtractedText
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
            
            // Detect character cue lines (pure ALL-CAPS) – but exclude narrative
            // action lines that start with a name followed by lowercase
            // narrative such as "JESSICA (30s …) bounds in …".
            if !startsWithCapsNameAndNarrative(line) &&
               (isCharacterName(line) || (i > 0 && isAllCapsNameAtStartOfLine(line))) &&
               !isSceneHeading(line) {
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
        // TODO: Replace with sections derived from processExtractedText
        return processedSections
    }
    
    // MARK: - Text Processing (Original - May need removal/adaptation)
    
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
    
    // MARK: - PDF Processing with Vision
    
    /// Extracts text using Vision framework to get layout information.
    /// - Parameter pdfURL: URL of the PDF file to process.
    /// - Returns: An array of Paragraphs for each page (or potentially ScriptSections later).
    ///   Note: This example modifies the function to be synchronous for simplicity,
    ///   but real-world use might require asynchronous handling.
    static func extractTextWithLayout(from pdfURL: URL) -> [Int: [Paragraph]] {
        guard let pdf = PDFDocument(url: pdfURL) else {
            print("DEBUG: Could not load PDF")
            return [:]
        }
        
        var allPageParagraphs: [Int: [Paragraph]] = [:]
        
        print("DEBUG: Processing PDF with \(pdf.pageCount) pages using Vision...")
        
        for i in 0..<pdf.pageCount {
            guard let page = pdf.page(at: i) else {
                print("DEBUG: Could not get page \(i)")
                continue
            }
            
            // 1. Convert PDF page to image
            let pageRect = page.bounds(for: .mediaBox)
            // Increase resolution for better OCR - adjust scale as needed
            let scale: CGFloat = 2.0
            let imageSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
            
            let renderer = UIGraphicsImageRenderer(size: imageSize)
            let pageImage = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(CGRect(origin: .zero, size: imageSize))
                
                ctx.cgContext.translateBy(x: 0, y: imageSize.height)
                ctx.cgContext.scaleBy(x: scale, y: -scale) // Apply scale here
                
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            
            print("DEBUG: Generated image for page \(i+1) with size \(imageSize)")
            
            // 2. Use Vision framework for text recognition with layout
            // Using a semaphore to wait for the async Vision task (simplification for this example)
            let semaphore = DispatchSemaphore(value: 0)
            var pageParagraphs: [Paragraph] = []
            
            performTextRecognition(on: pageImage, pageIndex: i) { paragraphs in
                pageParagraphs = paragraphs
                semaphore.signal()
            }
            
            _ = semaphore.wait(timeout: .distantFuture) // Wait for Vision to complete
            allPageParagraphs[i] = pageParagraphs
            print("DEBUG: Finished Vision processing for page \(i+1), found \(pageParagraphs.count) paragraphs.")
        }
        
        print("DEBUG: Finished processing all pages.")
        return allPageParagraphs
    }

    /// Performs text recognition on a given image using Vision.
    private static func performTextRecognition(on image: UIImage, pageIndex: Int, completion: @escaping ([Paragraph]) -> Void) {
        guard let cgImage = image.cgImage else {
            print("DEBUG: Could not get CGImage for page \(pageIndex + 1)")
            completion([])
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                print("DEBUG: Vision request failed or no observations for page \(pageIndex + 1). Error: \(error?.localizedDescription ?? "Unknown")")
                completion([])
                return
            }
            
            var textBlocks: [TextBlock] = []
            
            for observation in observations {
                if let recognizedText = observation.topCandidates(1).first {
                    let boundingBox = observation.boundingBox // Normalized coordinates
                    
                    // Convert normalized coordinates to image coordinates (origin top-left)
                    let imgWidth = image.size.width
                    let imgHeight = image.size.height
                    let x = boundingBox.origin.x * imgWidth
                    let y = (1 - boundingBox.origin.y - boundingBox.height) * imgHeight // Invert Y
                    let width = boundingBox.width * imgWidth
                    let height = boundingBox.height * imgHeight
                    
                    let block = TextBlock(
                        text: recognizedText.string,
                        boundingBox: CGRect(x: x, y: y, width: width, height: height),
                        confidence: recognizedText.confidence
                    )
                    textBlocks.append(block)
                }
            }
            
            print("DEBUG: Page \(pageIndex + 1): Found \(textBlocks.count) raw text blocks from Vision.")
            
            // Group raw blocks into lines using spatial clustering
            let textLines = groupIntoLines(textBlocks)
            print("DEBUG: Page \(pageIndex + 1): Grouped into \(textLines.count) lines.")
            
            // Group lines into paragraphs using spatial clustering
            let paragraphs = groupIntoParagraphs(textLines)
            print("DEBUG: Page \(pageIndex + 1): Grouped into \(paragraphs.count) paragraphs.")

            // Process the paragraphs to identify screenplay structure (placeholder)
            processExtractedText(paragraphs, for: pageIndex)

            completion(paragraphs) // Return the structured paragraphs
        }
        
        // Configure request
        request.recognitionLevel = .accurate // Or .fast
        request.usesLanguageCorrection = true
        // Add languages if needed, e.g., request.recognitionLanguages = ["en-US", "fr-FR"]

        // Perform request
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try requestHandler.perform([request])
        } catch {
            print("DEBUG: Failed to perform Vision request for page \(pageIndex + 1): \(error)")
            completion([])
        }
    }

    // MARK: - Spatial Grouping Logic

    /// Groups individual TextBlocks into TextLines based on vertical proximity.
    private static func groupIntoLines(_ blocks: [TextBlock], lineProximityThreshold: CGFloat = 10.0) -> [TextLine] {
        guard !blocks.isEmpty else { return [] }

        // Sort blocks primarily by Y coordinate, then X for tie-breaking
        let sortedBlocks = blocks.sorted {
            if abs($0.boundingBox.midY - $1.boundingBox.midY) < lineProximityThreshold {
                return $0.boundingBox.minX < $1.boundingBox.minX // Same line, sort by X
            }
            return $0.boundingBox.midY < $1.boundingBox.midY // Different lines, sort by Y
        }

        var lines: [TextLine] = []
        var currentLine = TextLine()

        for block in sortedBlocks {
            if currentLine.blocks.isEmpty {
                // First block always starts a new line
                currentLine.blocks.append(block)
            } else {
                // Check if the block is vertically close enough to the current line's center
                let currentLineCenterY = currentLine.boundingBox.midY
                if abs(block.boundingBox.midY - currentLineCenterY) < lineProximityThreshold {
                    // Add block to the current line
                    currentLine.blocks.append(block)
                } else {
                    // Block is too far vertically, finish the current line and start a new one
                    if !currentLine.blocks.isEmpty {
                        // Sort blocks within the completed line by X before adding
                        currentLine.blocks.sort { $0.boundingBox.minX < $1.boundingBox.minX }
                        lines.append(currentLine)
                    }
                    currentLine = TextLine(blocks: [block]) // Start new line with current block
                }
            }
        }

        // Add the last processed line
        if !currentLine.blocks.isEmpty {
            currentLine.blocks.sort { $0.boundingBox.minX < $1.boundingBox.minX }
            lines.append(currentLine)
        }

        return lines
    }

    /// Groups TextLines into Paragraphs based on vertical spacing.
    private static func groupIntoParagraphs(_ lines: [TextLine], paragraphSpacingThreshold: CGFloat = 15.0) -> [Paragraph] {
         guard !lines.isEmpty else { return [] }

         // Lines should already be sorted vertically by groupIntoLines
         var paragraphs: [Paragraph] = []
         var currentParagraph = Paragraph()

         for (index, line) in lines.enumerated() {
             if currentParagraph.lines.isEmpty {
                 // First line always starts a new paragraph
                 currentParagraph.lines.append(line)
             } else {
                 guard let previousLine = currentParagraph.lines.last else { continue } // Should always have a line

                 // Calculate vertical distance between the bottom of the previous line and the top of the current line
                 let verticalDistance = line.boundingBox.minY - previousLine.boundingBox.maxY

                 // Use line height as part of the threshold? Average line height could be calculated.
                 // For simplicity, using a fixed threshold for now.
                 if verticalDistance < paragraphSpacingThreshold {
                     // Lines are close enough, add to the current paragraph
                     currentParagraph.lines.append(line)
                 } else {
                     // Gap is too large, finish the current paragraph and start a new one
                     if !currentParagraph.lines.isEmpty {
                         paragraphs.append(currentParagraph)
                     }
                     currentParagraph = Paragraph(lines: [line]) // Start new paragraph
                 }
             }
         }

         // Add the last processed paragraph
         if !currentParagraph.lines.isEmpty {
             paragraphs.append(currentParagraph)
         }

         return paragraphs
     }

    // MARK: - Screenplay Structure Processing (Placeholder)

    /// Processes the grouped paragraphs to identify screenplay elements.
    /// This is where the core logic translation from the Python scripts would happen.
    private static func processExtractedText(_ paragraphs: [Paragraph], for pageIndex: Int) {
        print("DEBUG: Page \(pageIndex + 1): Processing \(paragraphs.count) paragraphs for screenplay structure...")

        for (index, paragraph) in paragraphs.enumerated() {
            // --- Placeholder Logic ---
            // Here you would analyze:
            // 1. Indentation: paragraph.boundingBox.minX relative to page width or common trends.
            // 2. Capitalization: paragraph.text.uppercased() == paragraph.text
            // 3. Keywords: paragraph.text.contains("INT."), paragraph.text.contains("EXT."), paragraph.text.contains("FADE IN"), etc.
            // 4. Line Structure: Number of lines, presence of colons (e.g., "NAME: Dialog").
            // 5. Column Detection: Check if multiple paragraphs have similar Y ranges but distinct X ranges.
            //    - This might require looking at TextLines across paragraphs or modifying grouping logic.
            // 6. Context: Analyze paragraph type based on the previous paragraph's type.

            // Example basic checks (very rudimentary):
            let text = paragraph.text
            let xPos = paragraph.boundingBox.minX
            let isAllCaps = text == text.uppercased() && text.rangeOfCharacter(from: .letters) != nil

            print("--- Paragraph \(index + 1) (X: \(Int(xPos)), Y: \(Int(paragraph.boundingBox.minY))) ---")
            print(text)

            if isAllCaps && (text.hasPrefix("INT.") || text.hasPrefix("EXT.") || text.hasPrefix("I/E.")) {
                 print("-> Potential Scene Heading")
            } else if isAllCaps && text.count < 50 && !text.contains("\n") && xPos > 150 && xPos < 400 { // Heuristic X range for character
                 print("-> Potential Character Cue")
            } else if text.contains(":") && !isAllCaps && xPos > 150 && xPos < 400 {
                 print("-> Potential Character Cue with inline Dialogue?") // Needs more robust check
            } else if isAllCaps && (text.contains("FADE") || text.contains("CUT TO") || text.contains("DISSOLVE")) {
                 print("-> Potential Transition")
            } else {
                 // Could be Action or Dialogue depending on context and indentation
                 // Need to track if the previous element was a Character Cue.
                 print("-> Potential Action/Dialogue")
            }
            print("--------------------")
            // --- End Placeholder ---

            // TODO: Replace placeholder logic with robust screenplay element identification
            //       based on the Python scripts' rules, using paragraph/line bounding boxes and text.
            //       This will involve creating final ScriptSection objects with the correct type.
        }
    }


    // MARK: - Original PDF Text Extraction (Fallback/Alternative)
    
    /// Extract text content from a PDF file using PDFKit's basic text extraction.
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
        // Note: This original function might be kept as a fallback if Vision fails,
        // or removed if Vision is the primary method.
        return fullText
    }
    
    // MARK: - Helper functions for screenplay parsing (Original - May need removal/adaptation)

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
