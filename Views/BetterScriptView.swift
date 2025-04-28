import SwiftUI
import PDFKit

struct ScriptParserView: View {
    @State private var screenplayText: String = ""
    @State private var parsedSections: [ScriptSection] = []
    @State private var currentSectionIndex = 0
    @State private var isLoading: Bool = true
    
    var body: some View {
        VStack {
            Text("Script Parser")
                .font(.largeTitle)
                .padding()
            
            if isLoading {
                ProgressView("Loading PDF...")
                    .padding()
                    .onAppear {
                        loadPDFContent()
                    }
            } else if !parsedSections.isEmpty {
                // Display the current section
                ScriptSectionView(section: parsedSections[currentSectionIndex])
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .padding()
                
                // Navigation buttons
                HStack {
                    Button(action: previousSection) {
                        Image(systemName: "arrow.left.circle.fill")
                            .resizable()
                            .frame(width: 44, height: 44)
                    }
                    .disabled(currentSectionIndex == 0)
                    .padding()
                    
                    Spacer()
                    
                    Text("\(currentSectionIndex + 1) / \(parsedSections.count)")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: nextSection) {
                        Image(systemName: "arrow.right.circle.fill")
                            .resizable()
                            .frame(width: 44, height: 44)
                    }
                    .disabled(currentSectionIndex >= parsedSections.count - 1)
                    .padding()
                }
                .padding(.horizontal)
            } else {
                Button("Parse Script") {
                    parsedSections = parseScreenplay(screenplayText)
                    currentSectionIndex = 0
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
    }
    
    private func loadPDFContent() {
        print("DEBUG: Starting PDF content loading...")
        // Get document directory URL
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let pdfURL = documentsDirectory.appendingPathComponent("fade.pdf")
        
        print("DEBUG: Looking for PDF at \(pdfURL.path)")
        // If PDF doesn't exist in Documents directory, look in the bundle
        if !fileManager.fileExists(atPath: pdfURL.path),
           let bundleURL = Bundle.main.url(forResource: "fade", withExtension: "pdf") {
            do {
                try fileManager.copyItem(at: bundleURL, to: pdfURL)
                print("DEBUG: Copied PDF from bundle to \(pdfURL.path)")
            } catch {
                print("DEBUG: Failed to copy PDF from bundle: \(error.localizedDescription)")
            }
        }
        
        // Load PDF document
        if let pdf = PDFDocument(url: pdfURL) {
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
            print("DEBUG: First 100 chars: \(String(fullText.prefix(100)))")
            
            // Debug format comparison with hardcoded example
            analyzeTextFormatting(pdfText: fullText)
            
            // Update state with the PDF content
            screenplayText = fullText
            parsedSections = parseScreenplay(fullText)
            print("DEBUG: Parsed into \(parsedSections.count) sections")
            
            // Debug the first few sections
            for (index, section) in parsedSections.prefix(3).enumerated() {
                print("DEBUG: Section \(index + 1) - Type: \(section.type), Length: \(section.text.count) chars")
                print("DEBUG: Section \(index + 1) - Preview: \(section.text.prefix(50))")
            }
            
            isLoading = false
        } else {
            print("DEBUG: Failed to load PDF document")
            // If PDF loading failed, use a fallback text for testing
            screenplayText = "Failed to load PDF content"
            parsedSections = parseScreenplay(screenplayText)
            isLoading = false
        }
    }
    
    private func analyzeTextFormatting(pdfText: String) {
        // Create a sample of hardcoded screenplay text (known to work)
        let sampleText = """
                              STARTUP MELTDOWN

                           Written by Assistant



FADE IN:

INT. TECH STARTUP OFFICE - MORNING

The office is buzzing with nervous energy. Banners reading
"LAUNCH DAY!" hang everywhere. SARAH (30s, CEO, stressed but
trying to appear calm) paces while checking her phone.

                         SARAH
          Has anyone seen the demo unit?
          Anyone?
"""
        
        print("\nDEBUG: === FORMAT COMPARISON ===")
        
        // Compare first few lines to see differences
        let sampleLines = sampleText.components(separatedBy: .newlines).prefix(15)
        let pdfLines = pdfText.components(separatedBy: .newlines).prefix(15)
        
        print("DEBUG: Sample (hardcoded) format:")
        for (i, line) in sampleLines.enumerated() {
            print("DEBUG: Sample[\(i)]: '\(line.replacingOccurrences(of: " ", with: "·"))'")
        }
        
        print("\nDEBUG: PDF format:")
        for (i, line) in pdfLines.enumerated() {
            print("DEBUG: PDF[\(i)]: '\(line.replacingOccurrences(of: " ", with: "·"))'")
        }
        
        // Check for character name formatting
        let sampleCharLines = sampleText.components(separatedBy: .newlines).filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.range(of: "^[A-Z0-9 ()]+$", options: .regularExpression) != nil && 
                   line.contains("         ")
        }
        
        let pdfCharLines = pdfText.components(separatedBy: .newlines).filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.range(of: "^[A-Z0-9 ()]+$", options: .regularExpression) != nil
        }
        
        print("\nDEBUG: Sample character lines (with centering):")
        for line in sampleCharLines.prefix(3) {
            print("DEBUG: '\(line.replacingOccurrences(of: " ", with: "·"))'")
        }
        
        print("\nDEBUG: PDF potential character lines (all caps):")
        for line in pdfCharLines.prefix(10) {
            print("DEBUG: '\(line.replacingOccurrences(of: " ", with: "·"))'")
        }
        
        print("\nDEBUG: === END FORMAT COMPARISON ===\n")
    }
    
    private func nextSection() {
        if currentSectionIndex < parsedSections.count - 1 {
            currentSectionIndex += 1
        }
    }
    
    private func previousSection() {
        if currentSectionIndex > 0 {
            currentSectionIndex -= 1
        }
    }
    
    private func parseScreenplay(_ text: String) -> [ScriptSection] {
        print("DEBUG: Starting screenplay parsing for text of length \(text.count)")
        var sections: [ScriptSection] = []
        var currentSectionText = ""
        var currentSectionType: SectionType = .narrator
        
        // Split the text into lines for processing
        let lines = text.components(separatedBy: .newlines)
        print("DEBUG: Split text into \(lines.count) lines")
        
        // Track if we've seen a scene heading (INT./EXT.) and dialog after it
        var seenSceneHeading = false
        var seenDialogAfterSceneHeading = false
        var characterLinesFound = 0
        var sceneHeadingsFound = 0
        
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines at the beginning
            if currentSectionText.isEmpty && trimmedLine.isEmpty {
                i += 1
                continue
            }
            
            // Check for scene headings (INT./EXT.)
            let isSceneHeading = !seenSceneHeading && (trimmedLine.starts(with: "INT.") || trimmedLine.starts(with: "EXT.") || trimmedLine.starts(with: "INT ") || trimmedLine.starts(with: "EXT "))
            if isSceneHeading {
                seenSceneHeading = true
                sceneHeadingsFound += 1
                print("DEBUG: Found scene heading at line \(i): \(trimmedLine)")
            }
            
            // Check if this line indicates a character's dialog
            let isCharLine = isCharacterLine(line)
            if isCharLine {
                characterLinesFound += 1
                print("DEBUG: Found character line at line \(i): \(trimmedLine)")
                
                // If this is the first dialog after a scene heading, finish the initial narrator section
                if seenSceneHeading && !seenDialogAfterSceneHeading {
                    seenDialogAfterSceneHeading = true
                    print("DEBUG: Marking first dialog after scene heading")
                    
                    // Add everything we've seen so far as the first narrator section
                    if !currentSectionText.isEmpty {
                        sections.append(ScriptSection(type: .narrator, text: currentSectionText))
                        print("DEBUG: Added narrator section with \(currentSectionText.count) chars")
                        currentSectionText = ""
                    }
                } else if seenDialogAfterSceneHeading {
                    // For subsequent dialogs, close any narrator section in progress
                    if !currentSectionText.isEmpty && currentSectionType == .narrator {
                        sections.append(ScriptSection(type: .narrator, text: currentSectionText))
                        print("DEBUG: Added subsequent narrator section with \(currentSectionText.count) chars")
                        currentSectionText = ""
                    }
                }
                
                // If we haven't seen a scene heading yet, just continue accumulating into the initial narrator block
                if !seenSceneHeading || !seenDialogAfterSceneHeading {
                    print("DEBUG: Not processing character line yet, adding to narrator section")
                    currentSectionText += line + "\n"
                    i += 1
                    continue
                }
                
                // Extract character name
                let characterName = trimmedLine
                
                // Collect dialog lines
                var dialogText = characterName + "\n"
                i += 1
                
                // Check if the next line is a parenthetical
                let hasParenthetical = i < lines.count && isParentheticalLine(lines[i])
                if hasParenthetical {
                    print("DEBUG: Found parenthetical: \(lines[i])")
                    dialogText += lines[i] + "\n"
                    i += 1
                }
                
                // Collect dialog content
                var dialogLineCount = 0
                while i < lines.count && !isCharacterLine(lines[i]) && !lines[i].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Debug the exact line content with representation of whitespace
                    let debugLine = lines[i].replacingOccurrences(of: " ", with: "·")
                    print("DEBUG: Dialog line: '\(debugLine)'")
                    dialogText += lines[i] + "\n"
                    dialogLineCount += 1
                    i += 1
                }
                print("DEBUG: Collected \(dialogLineCount) lines of dialog for character \(characterName)")
                
                sections.append(ScriptSection(type: .character, text: dialogText))
                print("DEBUG: Added character section with \(dialogText.count) chars")
                continue // Skip the normal increment
            } else {
                // This is part of the narrator text
                if currentSectionType != .narrator && seenDialogAfterSceneHeading {
                    // Start a new narrator section (only after we've started properly sectioning)
                    currentSectionText = ""
                    currentSectionType = .narrator
                }
                
                currentSectionText += line + "\n"
            }
            
            i += 1
        }
        
        // Add any remaining section
        if !currentSectionText.isEmpty {
            sections.append(ScriptSection(type: currentSectionType, text: currentSectionText))
            print("DEBUG: Added final section with \(currentSectionText.count) chars")
        }
        
        print("DEBUG: Parsing completed. Found \(sceneHeadingsFound) scene headings and \(characterLinesFound) character lines")
        print("DEBUG: Created \(sections.count) total sections")
        return sections
    }
    
    private func isCharacterLine(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip empty lines
        if trimmedLine.isEmpty {
            return false
        }
        
        // Character name criteria:
        // 1. All caps (traditional screenplay format)
        let isAllCaps = trimmedLine == trimmedLine.uppercased() && 
                        trimmedLine.range(of: "^[A-Z0-9 .,'()\\-]+$", options: .regularExpression) != nil
        
        // 2. Length is reasonable for a name (not too long, not too short)
        let hasReasonableLength = trimmedLine.count >= 2 && trimmedLine.count <= 35
        
        // 3. Either has centering spaces (traditional format) or is a standalone name (PDF format)
        let hasLeadingSpaces = line.contains("         ") // Multiple spaces indicating centering in hardcoded format
        let isPotentialCharName = !trimmedLine.contains(".") || 
                                 (trimmedLine.contains("(") && trimmedLine.contains(")"))
        
        // Combine criteria - either properly centered or PDF-style all caps name
        let isHardcodedFormat = hasLeadingSpaces && isAllCaps && hasReasonableLength
        let isPDFFormat = isAllCaps && hasReasonableLength && isPotentialCharName && 
                         !trimmedLine.starts(with: "INT") && !trimmedLine.starts(with: "EXT") &&
                         !trimmedLine.starts(with: "FADE")
        
        // Debug info
        if isAllCaps && hasReasonableLength && !hasLeadingSpaces && !isPDFFormat {
            print("DEBUG: Rejected potential PDF character name: \(trimmedLine)")
        }
        
        if isHardcodedFormat {
            print("DEBUG: Found hardcoded-style character line: \(trimmedLine)")
        }
        
        if isPDFFormat && !isHardcodedFormat {
            print("DEBUG: Found PDF-style character line: \(trimmedLine)")
        }
        
        return isHardcodedFormat || isPDFFormat
    }
    
    private func isParentheticalLine(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLine.hasPrefix("(") && trimmedLine.hasSuffix(")")
    }
}

struct ScriptSection: Identifiable {
    let id = UUID()
    let type: SectionType
    let text: String
}

enum SectionType {
    case narrator
    case character
}

struct ScriptSectionView: View {
    let section: ScriptSection
    
    var body: some View {
        VStack {
            Text(section.type == .narrator ? "NARRATOR" : "CHARACTER")
                .font(.headline)
                .padding(.bottom, 4)
            
            ScrollView {
                Text(section.text)
                    .font(.system(.body, design: .monospaced))
                    .multilineTextAlignment(.leading)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}