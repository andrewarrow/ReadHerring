import SwiftUI
import AVFoundation
import Foundation
import UIKit // Keep UIKit for openSettings
import PDFKit

// Using BetterScriptView.swift components

// Voices View Wrapper
struct VoicesViewWrapper: View {
    var moveToNextScreen: () -> Void
    @State private var voices: [AVSpeechSynthesisVoice] = []
    @State private var selectedVoice: AVSpeechSynthesisVoice?
    @State private var isPlaying: String? = nil
    @State private var editMode: EditMode = .active
    @State private var hiddenVoices: [String] = {
        let hidden = UserDefaults.standard.stringArray(forKey: "hiddenVoices") ?? []
        print("Loaded \(hidden.count) hidden voices from UserDefaults")
        return hidden
    }()
    @State private var showingReadAlongView = false
    
    private let sampleText = "To be or not to be, that is the question."
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    moveToNextScreen()
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                Text("Voices")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Empty spacer to maintain layout
                Spacer().frame(width: 50)
            }
            .padding(.top, 30)
            
            VStack(spacing: 4) {
                Text("Delete the voices you do not like")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom)
            
            if voices.isEmpty {
                Spacer()
                
                VStack(spacing: 30) {
                    Image(systemName: "exclamationmark.circle")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.orange)
                    
                    Text("No Premium Voices Found")
                        .font(.headline)
                    
                    Text("Please download enhanced voices in iOS Settings > Accessibility > Spoken Content > Voices")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                        
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
                }
                .padding()
                
                Spacer()
            } else {
                List {
                    ForEach(filteredVoices, id: \.identifier) { voice in
                        VoiceRowView(
                            voice: voice,
                            isPlaying: isPlaying == voice.identifier,
                            sampleText: sampleText,
                            onPlay: {
                                playVoice(voice)
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedVoice = voice
                        }
                        .listRowBackground(selectedVoice?.identifier == voice.identifier ? Color.blue.opacity(0.1) : Color.clear)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let voice = filteredVoices[index]
                            // Just add to hidden voices - don't modify the main voices array
                            hideVoice(voice)
                        }
                    }
                }
                .environment(\.editMode, .constant(.active))
                .environment(\.defaultMinListRowHeight, 80) // Give more height to rows for better tapping
            }
            
            if !voices.isEmpty {
                if hiddenVoices.count > 0 {
                    HStack {
                        Button(action: {
                            resetHiddenVoices()
                        }) {
                            Text("Reset Hidden Voices")
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            exportHiddenVoices()
                        }) {
                            Text("Export Hidden List")
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            importHiddenVoices()
                        }) {
                            Text("Import Hidden List")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                
                Button(action: {
                    // Launch the script parser view
                    navigateToReadAlongView()
                }) {
                    Text("Ready to Read")
                        .frame(minWidth: 200)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.bottom, 20)
                .disabled(false) // Remove the disabled state so user can proceed after deleting unwanted voices
            }
        }
        .onAppear {
            loadVoices()
        }
        .fullScreenCover(isPresented: $showingReadAlongView) {
            // Show the BetterScriptView with its default screenplay
            ScriptParserView()
        }
    }
    
    // Navigate to the script parser view
    private func navigateToReadAlongView() {
        // Show the script parser view as a full-screen cover
        showingReadAlongView = true
    }
    
    // Function to get the PDF URL from available locations
    private func getPDFURL() -> URL {
        // Try to get the PDF from multiple locations in this order:
        // 1. Documents directory (where it might be copied by prepareSamplePDF)
        // 2. App Bundle
        // 3. Project directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("fade.pdf")
        let bundleURL = Bundle.main.url(forResource: "fade", withExtension: "pdf")
        let projectURL = URL(fileURLWithPath: Bundle.main.bundlePath)
            .deletingLastPathComponent()
            .appendingPathComponent("fade.pdf")
        
        if FileManager.default.fileExists(atPath: documentsURL.path) {
            print("Using PDF from Documents directory")
            return documentsURL
        } else if let url = bundleURL {
            print("Using PDF from app bundle")
            return url
        } else if FileManager.default.fileExists(atPath: projectURL.path) {
            print("Using PDF from project directory")
            return projectURL
        } else {
            // If can't find the PDF anywhere, create a fallback URL
            print("Warning: Could not find fade.pdf, defaulting to Documents directory path")
            return documentsURL
        }
    }
    
    // Convert PDF to scenes
    private func convertPDFToScenes(url: URL) -> [Scene] {
        // Try to extract text from the PDF
        guard let pdf = PDFDocument(url: url) else {
            print("Failed to load PDF document")
            return [createErrorScene("Could not load PDF document")]
        }
        
        // Extract text from all pages of the PDF
        var fullText = ""
        for i in 0..<pdf.pageCount {
            if let page = pdf.page(at: i) {
                if let pageText = page.string {
                    fullText += pageText + "\n"
                }
            }
        }
        
        // If we have text, parse it into a screenplay
        if !fullText.isEmpty {
            print("Extracted \(fullText.count) characters of text from PDF")
            
            // Parse the text into a screenplay
            let screenplay = ScreenplayParser.parseScreenplay(text: fullText)
            
            // Use the scenes from the screenplay
            if !screenplay.scenes.isEmpty {
                print("Extracted \(screenplay.scenes.count) scenes from PDF")
                return screenplay.scenes
            } else {
                print("No scenes found in parsed screenplay")
            }
        } else {
            print("No text extracted from PDF")
        }
        
        // If we didn't extract scenes properly, create manual scenes from the PDF
        return createManualScenesFromPDF(pdf)
    }
    
    // Create a scene with error information
    private func createErrorScene(_ message: String) -> Scene {
        let errorScene = Scene(heading: "ERROR", description: message, location: "", timeOfDay: "")
        errorScene.addDialog(character: "SYSTEM", text: "Error: \(message)")
        return errorScene
    }
    
    // Create scenes manually by extracting text from PDF pages
    private func createManualScenesFromPDF(_ pdf: PDFDocument) -> [Scene] {
        var scenes: [Scene] = []
        
        // Create a scene for each page as a fallback method
        for i in 0..<pdf.pageCount {
            if let page = pdf.page(at: i) {
                if let pageText = page.string {
                    // Create a scene for this page
                    let scene = Scene(heading: "PAGE \(i+1)", 
                                    description: pageText.prefix(100) + "...",
                                    location: "PDF Page \(i+1)", 
                                    timeOfDay: "")
                    
                    // Try to extract dialog from the page text
                    extractDialogFromText(pageText, scene: scene)
                    
                    // Only add the scene if it has content
                    if !scene.dialogs.isEmpty {
                        scenes.append(scene)
                    }
                }
            }
        }
        
        if scenes.isEmpty {
            // If we couldn't extract anything, add an error scene
            scenes.append(createErrorScene("Could not extract content from PDF"))
        }
        
        return scenes
    }
    
    // Extract dialog from raw text
    private func extractDialogFromText(_ text: String, scene: Scene) {
        let lines = text.components(separatedBy: .newlines)
        var currentCharacter = ""
        var dialogLines: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            if trimmedLine.isEmpty {
                if !currentCharacter.isEmpty && !dialogLines.isEmpty {
                    // End of dialog, add it to the scene
                    let dialogText = dialogLines.joined(separator: " ")
                    scene.addDialog(character: currentCharacter, text: dialogText)
                    dialogLines = []
                    currentCharacter = ""
                }
                continue
            }
            
            // Check if this is a potential character name (ALL CAPS, not too long)
            if trimmedLine.uppercased() == trimmedLine && trimmedLine.count > 1 && trimmedLine.count < 50 {
                // End previous dialog if any
                if !currentCharacter.isEmpty && !dialogLines.isEmpty {
                    let dialogText = dialogLines.joined(separator: " ")
                    scene.addDialog(character: currentCharacter, text: dialogText)
                    dialogLines = []
                }
                
                // Set as current character
                currentCharacter = trimmedLine
            } 
            // If we have a character and this isn't a new character name, add to dialog
            else if !currentCharacter.isEmpty {
                dialogLines.append(trimmedLine)
            }
        }
        
        // Add any final dialog
        if !currentCharacter.isEmpty && !dialogLines.isEmpty {
            let dialogText = dialogLines.joined(separator: " ")
            scene.addDialog(character: currentCharacter, text: dialogText)
        }
    }
    
    // Return only voices that aren't hidden
    private var filteredVoices: [AVSpeechSynthesisVoice] {
        return voices.filter { !hiddenVoices.contains($0.identifier) }
    }
    
    private func hideVoice(_ voice: AVSpeechSynthesisVoice) {
        // Add to hidden voices if not already present
        if !hiddenVoices.contains(voice.identifier) {
            hiddenVoices.append(voice.identifier)
            // Save to UserDefaults and synchronize immediately
            UserDefaults.standard.set(hiddenVoices, forKey: "hiddenVoices")
            UserDefaults.standard.synchronize()
            
            print("Voice hidden: \(voice.name), ID: \(voice.identifier)")
            print("Total hidden voices: \(hiddenVoices.count)")
        }
        
        // If the hidden voice was selected, deselect it
        if selectedVoice?.identifier == voice.identifier {
            selectedVoice = nil
        }
    }
    
    private func unhideVoice(_ voice: AVSpeechSynthesisVoice) {
        // Remove from hidden voices if present
        if let index = hiddenVoices.firstIndex(of: voice.identifier) {
            hiddenVoices.remove(at: index)
            // Save to UserDefaults and synchronize immediately
            UserDefaults.standard.set(hiddenVoices, forKey: "hiddenVoices")
            UserDefaults.standard.synchronize()
            
            print("Voice unhidden: \(voice.name), ID: \(voice.identifier)")
            print("Total hidden voices: \(hiddenVoices.count)")
        }
    }
    
    private func loadVoices() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Filter to only show English premium/enhanced voices
        voices = allVoices.filter { voice in
            // Must be English language
            guard voice.language.starts(with: "en") else { return false }
            
            // Must be enhanced quality or have "premium" in the name
            return voice.quality == .enhanced || 
                   voice.name.lowercased().contains("premium") ||
                   voice.name.lowercased().contains("enhanced")
        }
        
        // Sort by name
        voices.sort { $0.name < $1.name }
        
        print("Loaded \(voices.count) premium English voices")
        print("Hidden voices identifiers: \(hiddenVoices)")
        for voice in voices {
            let isHidden = hiddenVoices.contains(voice.identifier) ? " (HIDDEN)" : ""
            print("Voice: \(voice.name), ID: \(voice.identifier), Quality: \(voice.quality.rawValue)\(isHidden)")
        }
        
        // If no voices found, try loading all voices
        if voices.isEmpty {
            loadAllVoices()
        }
    }
    
    // Fallback to load all English voices if no premium voices are available
    private func loadAllVoices() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Filter to only show English voices
        voices = allVoices.filter { $0.language.starts(with: "en") }
        
        // Sort by quality first, then by name
        voices.sort { (voice1, voice2) -> Bool in
            if voice1.quality == voice2.quality {
                return voice1.name < voice2.name
            }
            return voice1.quality.rawValue > voice2.quality.rawValue
        }
        
        print("Loaded \(voices.count) English voices (all qualities)")
        print("Hidden voices count: \(hiddenVoices.count)")
        for voice in voices {
            let isHidden = hiddenVoices.contains(voice.identifier) ? " (HIDDEN)" : ""
            print("Voice: \(voice.name), ID: \(voice.identifier), Quality: \(voice.quality.rawValue)\(isHidden)")
        }
    }
    
    private func playVoice(_ voice: AVSpeechSynthesisVoice) {
        // Stop any currently playing speech
        if isPlaying != nil {
            AVSpeechSynthesizer.shared.stopSpeaking(at: .immediate)
        }
        
        // Set the voice as playing
        isPlaying = voice.identifier
        
        // Create and configure utterance
        let utterance = AVSpeechUtterance(string: sampleText)
        utterance.voice = voice
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // Start speaking
        AVSpeechSynthesizer.shared.speak(utterance)
        
        // Set timer to stop playing status after a few seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if self.isPlaying == voice.identifier {
                self.isPlaying = nil
            }
        }
    }
    
    private func openSettings() {
        if let url = URL(string: "App-Prefs:root=ACCESSIBILITY&path=SPEECH") {
           UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    // Reset hidden voices and ensure the changes are persisted
    private func resetHiddenVoices() {
        hiddenVoices = []
        UserDefaults.standard.set(hiddenVoices, forKey: "hiddenVoices")
        UserDefaults.standard.synchronize()
        print("All hidden voices reset!")
        loadVoices() // Reload all voices
    }
    
    // Export the list of hidden voice IDs as a JSON file and share
    private func exportHiddenVoices() {
        // Create a map of voice names to IDs for better readability when viewing the file
        var voiceData: [[String: String]] = []
        
        // Include hidden voice data with name and ID
        for identifier in hiddenVoices {
            // Find corresponding voice if available
            if let voice = voices.first(where: { $0.identifier == identifier }) {
                voiceData.append([
                    "name": voice.name,
                    "identifier": identifier,
                    "language": voice.language
                ])
            } else {
                // If voice not found in current list, just include the ID
                voiceData.append([
                    "name": "Unknown",
                    "identifier": identifier,
                    "language": "unknown"
                ])
            }
        }
        
        // Create the final dictionary with metadata
        let exportData: [String: Any] = [
            "version": 1,
            "timestamp": Date().timeIntervalSince1970,
            "hiddenVoiceCount": hiddenVoices.count,
            "hiddenVoices": voiceData,
            "hiddenVoiceIds": hiddenVoices
        ]
        
        // First, try the simpler approach with direct string sharing
        let jsonStringToShare: String
        
        if JSONSerialization.isValidJSONObject(exportData) {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    jsonStringToShare = jsonString
                    shareText(jsonStringToShare, filename: "ReadHerring_HiddenVoices.json")
                    return
                }
            } catch {
                print("JSON serialization error: \(error)")
            }
        }
        
        // Fallback to showing an alert with error
        showAlert(title: "Export Failed", message: "Unable to prepare voice data for sharing")
    }
    
    // Share text content with a suggested filename
    private func shareText(_ text: String, filename: String) {
        // Create a temporary directory URL
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        do {
            // Write the text to the file
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            
            // Create a share activity view controller
            let activityViewController = UIActivityViewController(
                activityItems: [fileURL],
                applicationActivities: nil
            )
            
            // Configure for iPad presentation
            if let popoverController = activityViewController.popoverPresentationController {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootView = windowScene.windows.first?.rootViewController?.view {
                    popoverController.sourceView = rootView
                    popoverController.sourceRect = CGRect(
                        x: rootView.bounds.midX,
                        y: rootView.bounds.midY,
                        width: 0,
                        height: 0
                    )
                    popoverController.permittedArrowDirections = []
                }
            }
            
            // Present the share sheet
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(activityViewController, animated: true)
            }
            
        } catch {
            print("Failed to write temporary file: \(error)")
            showAlert(title: "Share Failed", message: "Could not prepare file for sharing: \(error.localizedDescription)")
        }
    }
    
    // Import hidden voice IDs from a JSON file
    private func importHiddenVoices() {
        // Create document picker to select a JSON file
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
        documentPicker.allowsMultipleSelection = false
        documentPicker.delegate = DocumentPickerDelegate { url in
            self.processImportedFile(at: url)
        }
        
        // Present the document picker
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(documentPicker, animated: true)
        }
    }
    
    // Process the imported JSON file
    private func processImportedFile(at url: URL) {
        do {
            let data = try Data(contentsOf: url)
            
            // Try to parse as JSON
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let importedIds = json["hiddenVoiceIds"] as? [String] {
                
                // Update hidden voices with imported IDs
                hiddenVoices = importedIds
                UserDefaults.standard.set(hiddenVoices, forKey: "hiddenVoices")
                UserDefaults.standard.synchronize()
                
                // Reload voices to apply changes
                loadVoices()
                
                // Show success message
                showAlert(title: "Import Successful", 
                         message: "Imported \(importedIds.count) hidden voice IDs.")
                
            } else {
                showAlert(title: "Import Failed", 
                         message: "The file does not contain valid hidden voice data.")
            }
        } catch {
            showAlert(title: "Import Failed", 
                     message: "Error reading file: \(error.localizedDescription)")
        }
    }
    
    // Helper function to show alerts
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        // Present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
}
