import SwiftUI
import PDFKit
import AVFoundation

struct ScriptParserView: View {
    @State private var screenplayText: String = ""
    @State private var parsedSections: [ScriptSection] = []
    @State private var currentSectionIndex = 0
    @State private var isLoading: Bool = true
    @State private var showingVoiceSelection = false
    @State private var selectedVoiceId: String? = nil
    @State private var currentCharacter: String = ""
    @State private var showingDocumentPicker = false
    @State private var selectedPDFPath: URL?
    
    var body: some View {
        VStack {
            HStack {
                Text("Script Parser")
                    .font(.largeTitle)
                    .padding()
                
                Spacer()
                
                Button(action: {
                    showingDocumentPicker = true
                }) {
                    Image(systemName: "doc.fill.badge.plus")
                        .font(.title2)
                        .padding()
                }
            }
            
            if isLoading {
                ProgressView("Loading PDF...")
                    .padding()
                    .onAppear {
                        loadPDFContent()
                    }
            } else if !parsedSections.isEmpty {
                // Display the current section
                ScriptSectionView(
                    section: parsedSections[currentSectionIndex], 
                    onChangeVoice: {
                        // Update current character for the voice selection modal
                        if parsedSections[currentSectionIndex].type == .narrator {
                            currentCharacter = CharacterVoices.NARRATOR_KEY
                        } else {
                            let lines = parsedSections[currentSectionIndex].text.components(separatedBy: .newlines)
                            if let firstLine = lines.first {
                                currentCharacter = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                        
                        // Get the current voice ID
                        if let voice = CharacterVoices.shared.getVoiceFor(character: currentCharacter) {
                            selectedVoiceId = voice.identifier
                        }
                        
                        // Show voice selection modal
                        showingVoiceSelection = true
                    }
                )
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
        .sheet(isPresented: $showingVoiceSelection) {
            VoiceSelectionView(character: currentCharacter, selectedVoiceId: $selectedVoiceId)
                .onDisappear {
                    // Update voice mapping when selection modal is dismissed
                    if let voiceId = selectedVoiceId,
                       let selectedVoice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.identifier == voiceId }) {
                        CharacterVoices.shared.setVoice(character: currentCharacter, voice: selectedVoice)
                        
                        // Speak the current section with the new voice
                        speakCurrentSection()
                    }
                }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPickerUI(onDocumentPicked: { url in
                // Reset view state
                isLoading = true
                selectedPDFPath = url
                
                // Process the selected PDF
                loadPDFContent(from: url)
            })
        }
        .onChange(of: currentSectionIndex) { _ in
            // Speak the text when navigating between sections
            speakCurrentSection()
        }
    }
    
    private func speakCurrentSection() {
        // Stop any currently playing speech
        AVSpeechSynthesizer.shared.stopSpeaking(at: .immediate)
        
        // Get the current section and determine character
        guard currentSectionIndex < parsedSections.count else { return }
        
        let section = parsedSections[currentSectionIndex]
        let character: String
        let textToSpeak: String
        
        if section.type == .narrator {
            character = CharacterVoices.NARRATOR_KEY
            textToSpeak = section.text
        } else {
            // For character dialog, extract name and dialog
            let lines = section.text.components(separatedBy: .newlines)
            if lines.count < 2 { return }
            
            character = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip the character name line and join the rest
            textToSpeak = lines.dropFirst().joined(separator: " ")
        }
        
        // Get the voice for this character
        guard let voice = CharacterVoices.shared.getVoiceFor(character: character) else { return }
        
        // Clean text by removing stage directions (text in parentheses)
        var cleanTextToSpeak = textToSpeak.replacingOccurrences(
            of: "\\(.*?\\)",
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Replace INT. with "interior" and EXT. with "exterior" for narration
        if character == CharacterVoices.NARRATOR_KEY {
            cleanTextToSpeak = cleanTextToSpeak.replacingOccurrences(of: "INT.", with: "Interior")
            cleanTextToSpeak = cleanTextToSpeak.replacingOccurrences(of: "EXT.", with: "Exterior")
        }
        
        // Create and configure the utterance
        let utterance = AVSpeechUtterance(string: cleanTextToSpeak)
        utterance.voice = voice
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // Speak the text
        AVSpeechSynthesizer.shared.speak(utterance)
    }
    
    private func loadPDFContent(from customURL: URL? = nil) {
        print("DEBUG: Starting PDF content loading...")
        // Get document directory URL
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Determine which PDF to load
        var pdfURL: URL
        
        if let customURL = customURL {
            // Use the provided custom URL
            pdfURL = customURL
            print("DEBUG: Using custom PDF at \(pdfURL.path)")
        } else {
            // Use the default PDF path
            pdfURL = documentsDirectory.appendingPathComponent("fade.pdf")
            
            print("DEBUG: Looking for PDF at \(pdfURL.path)")
            // If default PDF doesn't exist in Documents directory, look in the bundle
            if !fileManager.fileExists(atPath: pdfURL.path),
               let bundleURL = Bundle.main.url(forResource: "fade", withExtension: "pdf") {
                do {
                    try fileManager.copyItem(at: bundleURL, to: pdfURL)
                    print("DEBUG: Copied PDF from bundle to \(pdfURL.path)")
                } catch {
                    print("DEBUG: Failed to copy PDF from bundle: \(error.localizedDescription)")
                }
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
            
            // Assign random voices for narrator and characters
            assignInitialVoices()
            
            isLoading = false
        } else {
            print("DEBUG: Failed to load PDF document")
            // If PDF loading failed, use a fallback text for testing
            screenplayText = "Failed to load PDF content"
            parsedSections = parseScreenplay(screenplayText)
            isLoading = false
        }
    }
    
    private func assignInitialVoices() {
        // Reset the used voice tracking to ensure we start fresh
        CharacterVoices.shared.resetUsedVoices()
        
        // Ensure narrator has a male voice
        if CharacterVoices.shared.getVoiceFor(character: CharacterVoices.NARRATOR_KEY) == nil {
            if let maleVoice = CharacterVoices.shared.getRandomVoice(gender: "M") {
                CharacterVoices.shared.setVoice(character: CharacterVoices.NARRATOR_KEY, voice: maleVoice)
            }
        }
        
        // Create a set to keep track of characters we've already processed
        var processedCharacters = Set<String>()
        
        // First, collect all character names and their genders
        var characters: [(name: String, gender: String)] = []
        
        for section in parsedSections {
            if section.type == .character {
                // Extract character name from first line
                let lines = section.text.components(separatedBy: .newlines)
                if let firstLine = lines.first {
                    let character = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !processedCharacters.contains(character) {
                        // Determine likely gender from character name
                        let gender = detectGenderFromName(character)
                        characters.append((name: character, gender: gender))
                        processedCharacters.insert(character)
                    }
                }
            }
        }
        
        // Clear processed characters to reuse when assigning voices
        processedCharacters.removeAll()
        
        // Sort characters by gender to group similar genders together
        let sortedCharacters = characters.sorted { $0.gender < $1.gender }
        
        // Now assign voices to each character
        for (character, gender) in sortedCharacters {
            if !processedCharacters.contains(character) {
                if let voice = CharacterVoices.shared.getVoiceFor(character: character, gender: gender) {
                    CharacterVoices.shared.setVoice(character: character, voice: voice)
                    processedCharacters.insert(character)
                }
            }
        }
    }
    
    // Helper function to determine gender from character name
    private func detectGenderFromName(_ name: String) -> String {
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
                while i < lines.count {
                    let nextLine = lines[i]
                    let trimmedNextLine = nextLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Stop if line is empty
                    if trimmedNextLine.isEmpty {
                        i += 1
                        break
                    }
                    
                    // Stop if next line is another character name
                    if isCharacterLine(nextLine) {
                        break
                    }
                    
                    // Stop if next line contains a character name in all caps followed by description
                    // Like: "MIKE (20s, software engineer, disheveled) rushes in"
                    let containsCharacterDescription = 
                        trimmedNextLine.range(of: "[A-Z]{2,}\\s*\\([^\\)]+\\)", options: .regularExpression) != nil &&
                        trimmedNextLine.lowercased() != trimmedNextLine
                    
                    // Stop if line looks like a scene heading
                    let isSceneHeadingLine = 
                        trimmedNextLine.starts(with: "INT") || 
                        trimmedNextLine.starts(with: "EXT") || 
                        trimmedNextLine.starts(with: "FADE")
                    
                    if containsCharacterDescription || isSceneHeadingLine {
                        break
                    }
                    
                    // Debug the exact line content with representation of whitespace
                    let debugLine = nextLine.replacingOccurrences(of: " ", with: "·")
                    print("DEBUG: Dialog line: '\(debugLine)'")
                    
                    dialogText += nextLine + "\n"
                    dialogLineCount += 1
                    i += 1
                }
                print("DEBUG: Collected \(dialogLineCount) lines of dialog for character \(characterName)")
                
                sections.append(ScriptSection(type: .character, text: dialogText))
                print("DEBUG: Added character section with \(dialogText.count) chars")
                
                // Create a new narrator section for any text after the dialog
                currentSectionType = .narrator
                currentSectionText = ""
                
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
    let onChangeVoice: () -> Void
    
    // Extract the character name for character sections
    private var characterName: String {
        if section.type == .narrator {
            return CharacterVoices.NARRATOR_KEY
        } else {
            // For character sections, extract name from first line
            let lines = section.text.components(separatedBy: .newlines)
            if let firstLine = lines.first {
                return firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return "UNKNOWN"
    }
    
    // Get the current voice for this character
    private var currentVoice: String {
        return CharacterVoices.shared.getVoiceNameFor(character: characterName)
    }
    
    var body: some View {
        VStack {
            Text(section.type == .narrator ? "NARRATOR" : characterName)
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
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Text("Voice: \(currentVoice)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: onChangeVoice) {
                        Label("Change Voice", systemImage: "person.wave.2")
                            .font(.footnote)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground).opacity(0.9))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        )
    }
}