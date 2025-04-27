import SwiftUI
import PDFKit
import Vision
import UniformTypeIdentifiers

class Scene {
    var heading: String
    var description: String
    var location: String
    var timeOfDay: String
    var sceneNumber: String?
    
    init(heading: String, description: String, location: String, timeOfDay: String, sceneNumber: String? = nil) {
        self.heading = heading
        self.description = description
        self.location = location
        self.timeOfDay = timeOfDay
        self.sceneNumber = sceneNumber
    }
}

struct Character {
    var name: String
    var lineCount: Int
    var totalWords: Int
    var firstAppearance: Int // Scene index
}

struct ScreenplaySummary {
    var sceneCount: Int
    var scenes: [Scene]
    var characterCount: Int
    var characters: [String: Character]
    var rawText: String
}

struct ContentView: View {
    @State private var selectedURL: URL?
    @State private var extractedText: String = ""
    @State private var isProcessing = false
    @State private var progress: Float = 0.0
    @State private var screenplaySummary: ScreenplaySummary?
    @State private var showOnboarding = true
    
    var body: some View {
        ZStack {
            if showOnboarding {
                OnboardingView(showOnboarding: $showOnboarding)
            } else {
                VStack {
                    if isProcessing {
                        VStack {
                            Text("Processing PDF...")
                                .font(.headline)
                                .padding(.bottom, 8)
                            
                            ProgressView(value: progress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(height: 20)
                            
                            Text("\(Int(progress * 100))%")
                                .font(.subheadline)
                                .padding(.top, 8)
                        }
                        .padding()
                    } else if let summary = screenplaySummary {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Screenplay Analysis")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .padding(.bottom, 8)
                                
                                Group {
                                    Text("Total Scenes: \(summary.sceneCount)")
                                        .font(.headline)
                                        .padding(.top, 4)
                                    
                                    if !summary.scenes.isEmpty {
                                        Text("Scene Locations:")
                                            .font(.headline)
                                            .padding(.top, 4)
                                        
                                        ForEach(summary.scenes.prefix(5), id: \.heading) { scene in
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("• \(scene.heading)")
                                                    .font(.body)
                                                    .fontWeight(.semibold)
                                                
                                                Text("  Location: \(scene.location)")
                                                    .font(.body)
                                                    .foregroundColor(.secondary)
                                                
                                                Text("  Time: \(scene.timeOfDay)")
                                                    .font(.body)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.bottom, 4)
                                        }
                                        
                                        if summary.sceneCount > 5 {
                                            Text("...and \(summary.sceneCount - 5) more scenes")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .padding(.top, 2)
                                        }
                                    }
                                }
                                
                                Divider()
                                    .padding(.vertical, 8)
                                
                                Group {
                                    Text("Total Characters: \(summary.characterCount)")
                                        .font(.headline)
                                        .padding(.top, 4)
                                    
                                    if !summary.characters.isEmpty {
                                        Text("Main Characters:")
                                            .font(.headline)
                                            .padding(.top, 4)
                                        
                                        let sortedCharacters = summary.characters.values.sorted { 
                                            $0.lineCount > $1.lineCount 
                                        }.prefix(10)
                                        
                                        ForEach(sortedCharacters, id: \.name) { character in
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("• \(character.name)")
                                                    .font(.body)
                                                    .fontWeight(.semibold)
                                                
                                                Text("  \(character.lineCount) lines (\(character.totalWords) words)")
                                                    .font(.body)
                                                    .foregroundColor(.secondary)
                                                
                                                Text("  First appears in scene \(character.firstAppearance + 1)")
                                                    .font(.body)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.bottom, 4)
                                        }
                                        
                                        if summary.characterCount > 10 {
                                            Text("...and \(summary.characterCount - 10) more characters")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .padding(.top, 2)
                                        }
                                    }
                                }
                                
                                Divider()
                                    .padding(.vertical, 8)
                                    
                                Group {
                                    Text("Text Sample:")
                                        .font(.headline)
                                        .padding(.top, 4)
                                    
                                    Text(summary.rawText.prefix(300) + "...")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 2)
                                    
                                    Button(action: {
                                        saveExtractedText(summary.rawText)
                                    }) {
                                        Text("Save Extracted Text")
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.blue)
                                            .cornerRadius(8)
                                    }
                                    .padding(.top, 10)
                                }
                            }
                            .padding()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack {
                            Button("Select PDF") {
                                let picker = DocumentPickerViewController { url in
                                    self.selectedURL = url
                                    self.isProcessing = true
                                    self.progress = 0.0
                                    
                                    Task {
                                        await processPDF(url: url)
                                    }
                                }
                                
                                let scenes = UIApplication.shared.connectedScenes
                                let windowScene = scenes.first as? UIWindowScene
                                let window = windowScene?.windows.first
                                window?.rootViewController?.present(picker, animated: true)
                            }
                            .padding()
                            
                            Button(action: {
                                showOnboarding = true
                            }) {
                                Text("Show Setup Instructions")
                                    .font(.footnote)
                                    .foregroundColor(.blue)
                            }
                            .padding(.top, 8)
                        }
                    }
                }
            }
        }
    }
    
    func processPDF(url: URL) async {
        // Start accessing security-scoped resource if needed
        let securitySuccess = url.startAccessingSecurityScopedResource()
        defer {
            if securitySuccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Create a local file URL in the app's documents directory
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = url.lastPathComponent
        let localURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            if fileManager.fileExists(atPath: localURL.path) {
                try fileManager.removeItem(at: localURL)
            }
            try fileManager.copyItem(at: url, to: localURL)
        } catch {
            await MainActor.run {
                isProcessing = false
                extractedText = "Failed to copy PDF: \(error.localizedDescription)"
            }
            return
        }
        
        guard let pdf = PDFDocument(url: localURL) else {
            await MainActor.run {
                isProcessing = false
                extractedText = "Failed to load PDF"
            }
            return
        }
        
        let pageCount = pdf.pageCount
        var fullText = ""
        
        for i in 0..<pageCount {
            // Update progress at the beginning of each iteration
            await MainActor.run {
                progress = Float(i) / Float(pageCount)
            }
            
            autoreleasepool {
                if let page = pdf.page(at: i) {
                    let pageText = page.string ?? ""
                    
                    if !pageText.isEmpty {
                        fullText += pageText + "\n"
                    } else {
                        // Use OCR for this page
                        let pageImage = page.thumbnail(of: CGSize(width: 1024, height: 1024), for: .mediaBox)
                        if let cgImage = pageImage.cgImage {
                            let ocrText = performOCR(on: pageImage)
                            fullText += ocrText + "\n"
                        }
                    }
                }
            }
            
            // Small delay to allow UI updates
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        // Set progress to 100% at the end
        await MainActor.run {
            progress = 1.0
        }
        
        // Parse screenplay structure
        let summary = parseScreenplay(text: fullText)
        
        await MainActor.run {
            isProcessing = false
            extractedText = fullText
            screenplaySummary = summary
        }
    }
    
    func parseScreenplay(text: String) -> ScreenplaySummary {
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
                    let isNextLineParenthetical = nextLine.hasPrefix("(") || (nextLine.contains("(") && nextLine.contains(")"))
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
    
    func performOCR(on image: UIImage) -> String {
        let requestHandler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        
        var recognizedText = ""
        
        try? requestHandler.perform([request])
        
        if let results = request.results as? [VNRecognizedTextObservation] {
            for observation in results {
                if let topCandidate = observation.topCandidates(1).first {
                    recognizedText += topCandidate.string + " "
                }
            }
        }
        
        return recognizedText
    }
    
    func saveExtractedText(_ text: String) {
        // Get a path in Documents directory
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        
        // Create enhanced text with debug info
        let debugText = generateDebugText(text)
        
        // Save original text
        let fileName = "screenplay_\(timestamp).txt"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        // Save debug version
        let debugFileName = "screenplay_debug_\(timestamp).txt"
        let debugFileURL = documentsDirectory.appendingPathComponent(debugFileName)
        
        do {
            // Write both files
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            try debugText.write(to: debugFileURL, atomically: true, encoding: .utf8)
            
            // Share both files
            let activityVC = UIActivityViewController(
                activityItems: [fileURL, debugFileURL],
                applicationActivities: nil
            )
            
            // Present the share sheet
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(activityVC, animated: true)
            }
        } catch {
            print("Failed to save text: \(error.localizedDescription)")
        }
    }
    
    func generateDebugText(_ text: String) -> String {
        // Split text into lines for analysis
        let lines = text.components(separatedBy: .newlines)
        var result = "=== SCREENPLAY DEBUG ANALYSIS ===\n\n"
        
        // Regex patterns for scene headings
        let traditionalSceneRegex = try? NSRegularExpression(pattern: "^\\s*(INT\\.|EXT\\.|INT\\/EXT\\.|I\\/E|INTERIOR|EXTERIOR|INT |EXT )\\s+(.+?)(?:\\s+-\\s+(.+?))?(?:\\s+([0-9\\.]+\\s+[0-9\\.]+))?\\s*$", options: [.caseInsensitive])
        let numberedSceneRegex = try? NSRegularExpression(pattern: "^\\s*(?:SCENE|SC\\.?)\\s+([0-9]+)\\s*(.*)$", options: [.caseInsensitive])
        
        // Time indicators
        let timeIndicators = ["DAY", "NIGHT", "MORNING", "EVENING", "DUSK", "DAWN", "AFTERNOON", "CONTINUOUS", "LATER", "MOMENTS LATER"]
        
        // Process each line
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty {
                result += "[\(index+1)] EMPTY LINE\n"
                continue
            }
            
            // Check for potential scene heading
            var isSceneHeading = false
            if let sceneRegex = traditionalSceneRegex,
               sceneRegex.firstMatch(in: trimmedLine, options: [], range: NSRange(location: 0, length: trimmedLine.utf16.count)) != nil {
                result += "[\(index+1)] SCENE HEADING (Traditional): \(trimmedLine)\n"
                isSceneHeading = true
            } else if let numberedRegex = numberedSceneRegex,
                      numberedRegex.firstMatch(in: trimmedLine, options: [], range: NSRange(location: 0, length: trimmedLine.utf16.count)) != nil {
                result += "[\(index+1)] SCENE HEADING (Numbered): \(trimmedLine)\n"
                isSceneHeading = true
            } else if trimmedLine.uppercased() == trimmedLine && trimmedLine.count > 5 && trimmedLine.count < 100 {
                let hasIntExt = trimmedLine.contains("INT") || trimmedLine.contains("EXT") || 
                               trimmedLine.contains("INTERIOR") || trimmedLine.contains("EXTERIOR") ||
                               trimmedLine.contains("I/E") || trimmedLine.contains("INT/EXT")
                
                var hasTimeIndicator = false
                for indicator in timeIndicators {
                    if trimmedLine.contains(indicator) {
                        hasTimeIndicator = true
                        break
                    }
                }
                
                if (hasIntExt || hasTimeIndicator) && !trimmedLine.hasSuffix(":") && !trimmedLine.contains("TO:") {
                    result += "[\(index+1)] SCENE HEADING (All Caps): \(trimmedLine)\n"
                    isSceneHeading = true
                }
            }
            
            if !isSceneHeading {
                // Check for potential character name
                let isAllCaps = trimmedLine.uppercased() == trimmedLine && !trimmedLine.isEmpty
                let hasParenthetical = trimmedLine.contains("(") && trimmedLine.contains(")")
                
                if (isAllCaps || hasParenthetical) && trimmedLine.count < 50 {
                    // Filter known non-character elements
                    let isNotSceneHeading = !trimmedLine.contains("INT") && !trimmedLine.contains("EXT") && 
                                          !trimmedLine.contains("INTERIOR") && !trimmedLine.contains("EXTERIOR")
                    let isNotTransition = !trimmedLine.contains("CUT TO") && !trimmedLine.contains("FADE TO") && 
                                        !trimmedLine.contains("DISSOLVE") && !trimmedLine.hasSuffix(":")
                    
                    if isNotSceneHeading && isNotTransition && trimmedLine.components(separatedBy: .whitespaces).count <= 4 {
                        // Check if followed by potential dialogue
                        let hasDialogueAfter = index + 1 < lines.count && 
                                           !lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                                           lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines).uppercased() != 
                                           lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if hasDialogueAfter {
                            result += "[\(index+1)] CHARACTER: \(trimmedLine)\n"
                            
                            // Add a few lines of potential dialogue
                            var dialogueCount = 0
                            var i = index + 1
                            while i < lines.count && dialogueCount < 3 {
                                let nextLine = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                                if !nextLine.isEmpty && nextLine.uppercased() != nextLine {
                                    result += "  [\(i+1)] DIALOGUE: \(nextLine)\n"
                                    dialogueCount += 1
                                }
                                i += 1
                            }
                        } else {
                            result += "[\(index+1)] POSSIBLE CHARACTER (no dialogue): \(trimmedLine)\n"
                        }
                    } else if isAllCaps {
                        result += "[\(index+1)] ALL CAPS (not character): \(trimmedLine)\n"
                    }
                } else {
                    // Regular text line
                    result += "[\(index+1)] TEXT: \(trimmedLine.prefix(50))" + (trimmedLine.count > 50 ? "..." : "") + "\n"
                }
            }
        }
        
        return result
    }
}

// MARK: - OnboardingView
struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to ReadHerring")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            Text("Before you begin, you need to download voices in iOS Settings")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("This allows the app to read text aloud using high-quality voices")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: true) {
                Image("voices")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
                    .padding(.horizontal)
            }
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Text("Swipe left to right to see all options")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                openSettings()
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("Open Settings")
                }
                .frame(minWidth: 200)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.bottom, 12)
            
            Button(action: {
                showOnboarding = false
            }) {
                Text("Continue to App")
                    .frame(minWidth: 200)
                    .padding()
                    .background(Color.secondary.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
            }
            .padding(.bottom, 40)
        }
    }
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

class DocumentPickerViewController: UIDocumentPickerViewController, UIDocumentPickerDelegate {
    private var didPickDocumentHandler: (URL) -> Void
    
    init(didPickDocumentHandler: @escaping (URL) -> Void) {
        self.didPickDocumentHandler = didPickDocumentHandler
        let types: [UTType] = [UTType.pdf]
        super.init(forOpeningContentTypes: types, asCopy: false)
        self.delegate = self
        self.allowsMultipleSelection = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        // Start accessing the security-scoped resource
        let securitySuccess = url.startAccessingSecurityScopedResource()
        
        // Process the document
        didPickDocumentHandler(url)
        
        // Make sure to release the security-scoped resource when finished
        if securitySuccess {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
