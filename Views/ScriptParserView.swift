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
    @State private var isSpeaking: Bool = false
    @State private var currentScene: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and document picker button
            HStack {
                Text("Read Herring")
                    .font(.system(size: 18, weight: .medium))
                    .padding()
                    .foregroundColor(Color(UIColor.systemBackground))
                
                Spacer()
                
                Button(action: {
                    showingDocumentPicker = true
                }) {
                    Image(systemName: "doc.fill.badge.plus")
                        .font(.title2)
                        .foregroundColor(Color(UIColor.systemBackground))
                        .padding()
                }
            }
            .background(Color(UIColor.systemIndigo))
            
            if isLoading {
                // Loading state
                ProgressView("Loading PDF...")
                    .padding()
                    .onAppear {
                        loadPDFContent()
                    }
            } else if !parsedSections.isEmpty {
                // Main content view with script display
                scriptContentView
                
                // Bottom control bar
                controlBar
            } else {
                // Fall back to Parse Script button if no sections loaded
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
        .onAppear {
            // Initialize with default PDF if available
        }
    }
    
    // Script content area that displays the screenplay text
    private var scriptContentView: some View {
        ScrollView {
            scriptContentList
                .background(Color(UIColor.systemBackground))
        }
        .background(Color(UIColor.systemBackground))
        .onChange(of: currentSectionIndex) { newIndex in
            // Update current scene when section changes
            updateCurrentScene(for: newIndex)
        }
    }
    
    // Extracted content list to help compiler type-check
    private var scriptContentList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<parsedSections.count, id: \.self) { index in
                sectionView(for: index)
            }
        }
    }
    
    // Individual section view
    private func sectionView(for index: Int) -> some View {
        let section = parsedSections[index]
        
        return VStack(alignment: .leading, spacing: 0) {
            // Add line for each section
            if index > 0 {
                Divider()
            }
            
            // Section content
            contentView(for: section)
        }
        .padding(.vertical, 2)
        .background(backgroundColorFor(section: section, index: index))
        .id(index) // For scrolling to current section
    }
    
    // Determine background color based on section type, index, and color scheme
    @ViewBuilder
    private func backgroundColorFor(section: ScriptSection, index: Int) -> some View {
        if section.type == .character && index == currentSectionIndex {
            // Highlighted character section - light blue in TableRead
            Color(red: 0.85, green: 0.9, blue: 1.0)
        } else if index == currentSectionIndex {
            // Other highlighted sections - light yellow in TableRead
            Color(red: 1.0, green: 0.98, blue: 0.85)
        } else if section.type == .sceneHeading {
            // Scene headings have a dark background in TableRead
            Color.black
        } else {
            // Regular section background - white for narrative, alternate colors for character
            section.type == .character ? 
                Color(UIColor { $0.userInterfaceStyle == .dark ? .systemGray6 : .white }) : 
                Color(UIColor.systemBackground)
        }
    }
    
    // Content view for different section types
    private func contentView(for section: ScriptSection) -> some View {
        Group {
            if section.type == .character {
                characterSectionView(section: section)
            } else if section.type == .sceneHeading {
                sceneHeadingView(section: section)
            } else {
                narratorSectionView(section: section)
            }
        }
    }
    
    // Character dialog section formatting
    private func characterSectionView(section: ScriptSection) -> some View {
        let lines = section.text.components(separatedBy: .newlines)
        let character = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // Process dialog: join text but preserve paragraph breaks (double newlines)
        let dialogLines = lines.count > 1 ? Array(lines.dropFirst()) : []
        let processedDialog = processTextForWrapping(dialogLines)
        
        return VStack(alignment: .center, spacing: 4) {
            Text(character)
                .font(.custom("Courier", size: 14).bold())
                .foregroundColor(Color(UIColor.label))
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Text(processedDialog)
                .font(.custom("Courier", size: 13))
                .foregroundColor(Color(UIColor.label))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 40) // Wider horizontal padding for proper centering
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            // Set the current section and speak it
            currentSectionIndex = parsedSections.firstIndex(where: { $0.id == section.id }) ?? currentSectionIndex
            speakCurrentSection()
        }
    }
    
    // Helper to process text for proper wrapping
    private func processTextForWrapping(_ lines: [String]) -> String {
        var result = ""
        var previousLineEmpty = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty {
                // Only add one newline for empty lines and avoid consecutive empty lines
                if !previousLineEmpty && !result.isEmpty {
                    result += "\n"
                }
                previousLineEmpty = true
            } else {
                // If it's not the first line and the previous line wasn't empty, 
                // add a space instead of a newline
                if !result.isEmpty && !previousLineEmpty {
                    result += " "
                }
                result += trimmedLine
                previousLineEmpty = false
            }
        }
        
        return result
    }
    
    // Scene heading formatting
    private func sceneHeadingView(section: ScriptSection) -> some View {
        let processedText = processTextForWrapping(section.text.components(separatedBy: .newlines))
        
        return Text(processedText)
            .font(.custom("Courier", size: 13).bold())
            .foregroundColor(.white) // White text on black background like TableRead
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                currentSectionIndex = parsedSections.firstIndex(where: { $0.id == section.id }) ?? currentSectionIndex
                speakCurrentSection()
            }
    }
    
    // Narrator/action text formatting
    private func narratorSectionView(section: ScriptSection) -> some View {
        let processedText = processTextForWrapping(section.text.components(separatedBy: .newlines))
        
        return Text(processedText)
            .font(.custom("Courier", size: 13))
            .foregroundColor(Color(UIColor.label))
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                currentSectionIndex = parsedSections.firstIndex(where: { $0.id == section.id }) ?? currentSectionIndex
                speakCurrentSection()
            }
    }
    
    // Bottom control bar with playback controls
    private var controlBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 20) {
                // Record button
                Button(action: {
                    // Record functionality
                }) {
                    Image(systemName: "record.circle")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.red)
                }
                
                // Previous scene button
                Button(action: previousScene) {
                    Image(systemName: "backward.end.fill")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                
                // Previous line button
                Button(action: previousSection) {
                    Image(systemName: "backward.fill")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                
                // Play/pause button
                Button(action: togglePlayback) {
                    Image(systemName: isSpeaking ? "pause.fill" : "play.fill")
                        .resizable()
                        .frame(width: 25, height: 25)
                }
                
                // Next line button
                Button(action: nextSection) {
                    Image(systemName: "forward.fill")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                
                // Next scene button
                Button(action: nextScene) {
                    Image(systemName: "forward.end.fill")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                
                Spacer()
                
                // Section/total counter
                Text("\(currentSectionIndex + 1) / \(parsedSections.count)")
                    .font(.footnote)
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemIndigo).opacity(0.9))
            .foregroundColor(Color(UIColor.systemBackground))
            
            // Additional tabs for import, audio, characters, etc.
            HStack(spacing: 0) {
                tabButton(label: "Import", systemImage: "square.and.arrow.down")
                tabButton(label: "Audio", systemImage: "music.note")
                tabButton(label: "Characters", systemImage: "person.2")
                tabButton(label: "Notes", systemImage: "note.text")
                tabButton(label: "Scenes", systemImage: "list.bullet")
                tabButton(label: "Settings", systemImage: "gear")
            }
            .background(Color.orange)
            .foregroundColor(Color(UIColor.systemBackground))
        }
    }
    
    // Helper for tab buttons
    private func tabButton(label: String, systemImage: String) -> some View {
        Button(action: {
            // Tab action
        }) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                
                Text(label)
                    .font(.caption)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Navigation Functions
    
    private func togglePlayback() {
        if isSpeaking {
            AVSpeechSynthesizer.shared.stopSpeaking(at: .immediate)
            isSpeaking = false
        } else {
            speakCurrentSection()
        }
    }
    
    private func nextSection() {
        if currentSectionIndex < parsedSections.count - 1 {
            currentSectionIndex += 1
            speakCurrentSection()
        }
    }
    
    private func previousSection() {
        if currentSectionIndex > 0 {
            currentSectionIndex -= 1
            speakCurrentSection()
        }
    }
    
    private func nextScene() {
        // Find the next scene heading
        if let nextSceneIndex = parsedSections.firstIndex(where: { 
            $0.type == .sceneHeading && 
            parsedSections.firstIndex(of: $0)! > currentSectionIndex 
        }) {
            currentSectionIndex = nextSceneIndex
            speakCurrentSection()
        }
    }
    
    private func previousScene() {
        // Find the previous scene heading
        let reversedSections = parsedSections.prefix(currentSectionIndex).reversed()
        if let reversedIndex = reversedSections.firstIndex(where: { $0.type == .sceneHeading }) {
            let distanceFromStart = reversedSections.distance(from: reversedSections.startIndex, to: reversedIndex)
            let previousSceneIndex = currentSectionIndex - 1 - distanceFromStart
            currentSectionIndex = previousSceneIndex
            speakCurrentSection()
        }
    }
    
    private func updateCurrentScene(for sectionIndex: Int) {
        // Count how many scene headings we've passed to get to current section
        let sceneCount = parsedSections.prefix(through: sectionIndex).filter { $0.type == .sceneHeading }.count
        currentScene = max(0, sceneCount - 1)
    }
    
    // MARK: - Speech Synthesis
    
    private func speakCurrentSection() {
        // Stop any currently playing speech
        AVSpeechSynthesizer.shared.stopSpeaking(at: .immediate)
        
        // Get the current section and determine character
        guard currentSectionIndex < parsedSections.count else { return }
        
        let section = parsedSections[currentSectionIndex]
        let character: String
        let textToSpeak: String
        
        if section.type == .character {
            // For character dialog, extract name and dialog
            let lines = section.text.components(separatedBy: .newlines)
            if lines.count < 2 { 
                print("DEBUG: Character section has no dialog: \(section.text)")
                return 
            }
            
            character = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip the character name line and join the rest
            textToSpeak = lines.dropFirst().joined(separator: " ")
        } else {
            character = CharacterVoices.NARRATOR_KEY
            textToSpeak = section.text
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
        
        // Setup delegate to track speaking state
        AVSpeechSynthesizer.shared.delegate = SpeechDelegate(isSpeaking: $isSpeaking)
        
        // Speak the text
        AVSpeechSynthesizer.shared.speak(utterance)
        isSpeaking = true
    }
    
    // MARK: - PDF Processing
    
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
            
            // Update state with the PDF content
            screenplayText = fullText
            parsedSections = parseScreenplay(fullText)
            print("DEBUG: Parsed into \(parsedSections.count) sections")
            
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
    
    // MARK: - Voice Assignment
    
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
    
    // MARK: - Screenplay Parsing
    
    private func parseScreenplay(_ text: String) -> [ScriptSection] {
        print("DEBUG: Starting screenplay parsing for text of length \(text.count)")
        var sections: [ScriptSection] = []
        var currentSection = ""
        var currentType: SectionType = .narrator
        
        // Split the text into lines
        let lines = text.components(separatedBy: .newlines)
        
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines unless they're between sections
            if trimmedLine.isEmpty {
                // Add a newline to the current section buffer if it's not empty
                if !currentSection.isEmpty {
                    currentSection += "\n"
                }
                i += 1
                continue
            }
            
            // Check for scene headings (INT./EXT.)
            if isSceneHeading(line) {
                // If we have content in the buffer, add it as a section
                if !currentSection.isEmpty {
                    sections.append(ScriptSection(type: currentType, text: currentSection.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentSection = ""
                }
                
                // Start a new scene heading section
                currentType = .sceneHeading
                currentSection = line
                
                // Look ahead for additional scene heading lines
                var j = i + 1
                while j < lines.count && !isSceneHeading(lines[j]) && !isCharacterLine(lines[j]) && !lines[j].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    currentSection += "\n" + lines[j]
                    j += 1
                }
                
                // Add this completed scene heading
                sections.append(ScriptSection(type: .sceneHeading, text: currentSection.trimmingCharacters(in: .whitespacesAndNewlines)))
                currentSection = ""
                currentType = .narrator
                
                // Skip to the last processed line index in the next iteration
                i = j
                continue
            }
            
            // Check for character names
            if isCharacterLine(line) {
                // If we have content in the buffer, add it as a section
                if !currentSection.isEmpty {
                    sections.append(ScriptSection(type: currentType, text: currentSection.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentSection = ""
                }
                
                // Start a new character section with the character name
                currentType = .character
                currentSection = line
                
                // Look ahead for dialog lines
                var j = i + 1
                var consecutiveEmptyLines = 0
                
                // Process dialog until we hit another character, scene heading, or narrative description
                while j < lines.count && !isSceneHeading(lines[j]) && !isCharacterLine(lines[j]) {
                    let nextLine = lines[j]
                    let nextTrimmed = nextLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Track empty lines
                    if nextTrimmed.isEmpty {
                        consecutiveEmptyLines += 1
                    } else {
                        consecutiveEmptyLines = 0
                    }
                    
                    // Add dialog line if it's not empty
                    if !nextTrimmed.isEmpty {
                        // Check if this might be a narrative line (all caps description)
                        if isLikelyNarrative(nextTrimmed) {
                            break // Stop at narrative description
                        }
                        currentSection += "\n" + nextLine
                    } else if !currentSection.hasSuffix("\n\n") {
                        // Add at most one blank line to preserve formatting
                        currentSection += "\n"
                    }
                    
                    j += 1
                    
                    // If we've seen one or more consecutive blank lines followed by text, 
                    // it likely indicates the start of a new section
                    if consecutiveEmptyLines >= 1 && j < lines.count && 
                       !lines[j].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        break
                    }
                }
                
                // Add this completed character dialog
                sections.append(ScriptSection(type: .character, text: currentSection.trimmingCharacters(in: .whitespacesAndNewlines)))
                currentSection = ""
                currentType = .narrator
                
                // Skip to the last processed line index in the next iteration
                i = j
                continue
            }
            
            // For narration/action text
            if currentType != .narrator {
                // If we were building another type of section, finalize it
                if !currentSection.isEmpty {
                    sections.append(ScriptSection(type: currentType, text: currentSection.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentSection = ""
                }
                currentType = .narrator
            }
            
            // Add this line to the current narration section
            if !currentSection.isEmpty {
                currentSection += "\n"
            }
            currentSection += line
            
            // Increment counter for next iteration
            i += 1
        }
        
        // Add any remaining section
        if !currentSection.isEmpty {
            sections.append(ScriptSection(type: currentType, text: currentSection.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        
        return sections
    }
    
    private func isSceneHeading(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip empty lines
        if trimmedLine.isEmpty {
            return false
        }
        
        // Traditional scene heading patterns
        let sceneHeadingPatterns = [
            "^INT\\. ", "^EXT\\. ", "^INT\\./EXT\\. ", "^I/E ", 
            "^INTERIOR ", "^EXTERIOR ", "^INT ", "^EXT "
        ]
        
        for pattern in sceneHeadingPatterns {
            if trimmedLine.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return true
            }
        }
        
        // Special case for ALL CAPS scene headings that include DAY/NIGHT
        let timeIndicators = ["DAY", "NIGHT", "MORNING", "EVENING", "DUSK", "DAWN", "AFTERNOON", "CONTINUOUS", "LATER"]
        
        if trimmedLine == trimmedLine.uppercased() && !trimmedLine.contains("(") {
            for indicator in timeIndicators {
                if trimmedLine.contains(indicator) {
                    // Make sure this isn't a character name wrongly identified as scene heading
                    let hasSceneContext = trimmedLine.contains("ROOM") || 
                                          trimmedLine.contains("HOUSE") || 
                                          trimmedLine.contains("BUILDING") ||
                                          trimmedLine.contains("STREET") ||
                                          trimmedLine.contains("HALLWAY") ||
                                          trimmedLine.contains("OFFICE")
                    
                    if hasSceneContext {
                        return true
                    }
                }
            }
        }
        
        // Numbered scene headings like "SCENE 1" or "SC. 1"
        let numberedScenePattern = "^\\s*(SCENE|SC\\.?)\\s+([0-9]+)"
        if trimmedLine.range(of: numberedScenePattern, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }
        
        return false
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
                        trimmedLine.range(of: "^[A-Z0-9 .,'()\\-#]+$", options: .regularExpression) != nil
        
        // 2. Length is reasonable for a name
        let hasReasonableLength = trimmedLine.count >= 2 && trimmedLine.count <= 35
        
        // 3. Check for parenthetical character notes like "JOHN (O.S.)"
        let hasParenthetical = trimmedLine.contains("(") && trimmedLine.contains(")")
        
        // List of non-character elements to filter out
        let nonCharacterPhrases = [
            "FADE IN", "FADE OUT", "CUT TO", "DISSOLVE TO", "SMASH CUT", 
            "MATCH CUT", "INTERCUT", "TITLE", "SUPER", "MONTAGE", 
            "FLASHBACK", "END FLASHBACK", "DREAM SEQUENCE", "END DREAM",
            "CONTINUOUS", "SAME", "LATER", "MOMENTS LATER", "THAT NIGHT",
            "VERY FAST", "POV", "ANGLE ON", "CLOSE UP", "WIDE SHOT",
            "INT", "EXT", "INTERIOR", "EXTERIOR", "I/E", "INT/EXT"
        ]
        
        // Check if line contains any non-character phrases
        let containsNonCharacterPhrase = nonCharacterPhrases.contains { trimmedLine.contains($0) }
        
        // Check for sound effects (often in all caps)
        let isSoundEffect = trimmedLine.contains("!") || 
                           trimmedLine.contains("BAAM") || 
                           trimmedLine.contains("BOOM") ||
                           trimmedLine.contains("CRASH") ||
                           trimmedLine.contains("BANG")
        
        // Decide if this is a character name
        let isCharacterName = isAllCaps && 
                             hasReasonableLength && 
                             !containsNonCharacterPhrase && 
                             !isSoundEffect &&
                             (!trimmedLine.contains(".") || hasParenthetical) &&
                             !trimmedLine.hasSuffix(":") &&
                             !trimmedLine.hasSuffix("--")
        
        return isCharacterName
    }
    
    private func isLikelyNarrative(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip empty lines
        if trimmedLine.isEmpty {
            return false
        }
        
        // Check if it's a character description (usually in parentheses or all caps)
        if trimmedLine.contains("(") && trimmedLine.contains(")") && 
           (trimmedLine.contains("years old") || 
            trimmedLine.contains("20s") || 
            trimmedLine.contains("30s") || 
            trimmedLine.contains("40s") || 
            trimmedLine.contains("50s") || 
            trimmedLine.contains("engineer") || 
            trimmedLine.contains("student") || 
            trimmedLine.contains("professional") || 
            trimmedLine.contains("wearing")) {
            return true
        }
        
        // Check for common character intro patterns like "JOHN enters the room"
        let characterIntroPattern = "^[A-Z]{2,} +(enters|walks|sits|stands|looks|appears)"
        if trimmedLine.range(of: characterIntroPattern, options: .regularExpression) != nil {
            return true
        }
        
        // Check if the whole line is in ALL CAPS (often used for emphasis or character intro)
        let isAllCaps = trimmedLine == trimmedLine.uppercased() && trimmedLine.count > 10
        
        return isAllCaps
    }
}

struct ScriptSection: Identifiable, Equatable {
    let id = UUID()
    let type: SectionType
    let text: String
    
    static func == (lhs: ScriptSection, rhs: ScriptSection) -> Bool {
        return lhs.id == rhs.id
    }
}

enum SectionType {
    case narrator
    case character
    case sceneHeading
}

// A delegate class to track speech state
class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    @Binding var isSpeaking: Bool
    
    init(isSpeaking: Binding<Bool>) {
        self._isSpeaking = isSpeaking
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}