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
    
    var body: some View {
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
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
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
        
        // Regex patterns
        let sceneHeadingRegex = try? NSRegularExpression(pattern: "^\\s*(INT\\.|EXT\\.|INT\\/EXT\\.|I\\/E)\\s+(.+?)(?:\\s+-\\s+(.+?))?(?:\\s+([0-9\\.]+\\s+[0-9\\.]+))?\\s*$", options: [])
        
        // For extracting location and time from scene headings
        let locationTimeRegex = try? NSRegularExpression(pattern: "^(.+?)(?:\\s+-\\s+(.+?))?$", options: [])
        
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
            
            // Check if line is a scene heading
            if let sceneRegex = sceneHeadingRegex,
               let match = sceneRegex.firstMatch(in: trimmedLine, options: [], range: NSRange(location: 0, length: trimmedLine.utf16.count)) {
                
                // If we were building a scene, save it
                if let scene = currentScene {
                    // Trim and clean up scene description
                    scene.description = sceneDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    scenes.append(scene)
                }
                
                // Extract scene components
                let nsString = trimmedLine as NSString
                let fullHeading = nsString.substring(with: match.range)
                let locAndTime = match.range(at: 2).location != NSNotFound ? nsString.substring(with: match.range(at: 2)) : ""
                
                // Extract location and time of day
                var location = locAndTime
                var timeOfDay = ""
                
                if let locTimeRegex = locationTimeRegex,
                   let locTimeMatch = locTimeRegex.firstMatch(in: locAndTime, options: [], range: NSRange(location: 0, length: locAndTime.utf16.count)) {
                    let locTimeNS = locAndTime as NSString
                    location = locTimeMatch.range(at: 1).location != NSNotFound ? locTimeNS.substring(with: locTimeMatch.range(at: 1)) : ""
                    timeOfDay = locTimeMatch.range(at: 2).location != NSNotFound ? locTimeNS.substring(with: locTimeMatch.range(at: 2)) : ""
                }
                
                // Get scene number if present
                let sceneNumber = match.range(at: 4).location != NSNotFound ? nsString.substring(with: match.range(at: 4)) : nil
                
                // Create new scene
                currentScene = Scene(
                    heading: fullHeading,
                    description: "",
                    location: location,
                    timeOfDay: timeOfDay,
                    sceneNumber: sceneNumber
                )
                
                sceneDescription = ""
                currentSceneIndex += 1
                inDialogue = false
                continue
            }
            
            // Check if line is a character name (all caps, not a transition)
            if trimmedLine.uppercased() == trimmedLine && !trimmedLine.isEmpty {
                // Exclude scene headings and transitions
                let isNotSceneHeading = !trimmedLine.contains("INT.") && !trimmedLine.contains("EXT.")
                let isNotTransition = !trimmedLine.contains("CUT TO:") && !trimmedLine.contains("FADE TO:")
                
                if isNotSceneHeading && isNotTransition {
                    // Extract character name (remove parentheticals and (CONT'D))
                    var characterName = trimmedLine
                    
                    // Remove parentheticals
                    if let parenIndex = characterName.firstIndex(of: "(") {
                        characterName = String(characterName[..<parenIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    // Remove any non-alphabetic suffixes
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
                // Skip parentheticals
                if trimmedLine.hasPrefix("(") && trimmedLine.hasSuffix(")") {
                    continue
                }
                
                // Count dialogue
                dialogueLines += 1
                dialogueWords += trimmedLine.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
                
                if dialogueLines == 1 && index + 1 < lines.count {
                    // Check if there's more dialogue or it's a one-liner
                    let nextLine = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if nextLine.isEmpty || nextLine.hasPrefix("(") || nextLine.uppercased() == nextLine {
                        // End of dialogue, update character stats
                        if var character = characters[currentCharacter] {
                            character.lineCount += 1
                            character.totalWords += dialogueWords
                            characters[currentCharacter] = character
                        }
                        inDialogue = false
                    }
                } else if dialogueLines > 1 {
                    // Check if this is the end of a multi-line dialogue
                    if index + 1 < lines.count {
                        let nextLine = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                        if nextLine.isEmpty || nextLine.hasPrefix("(") || nextLine.uppercased() == nextLine {
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