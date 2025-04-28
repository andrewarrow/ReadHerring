import SwiftUI
import PDFKit
import Vision

class PDFProcessor {
    static func performOCR(on image: UIImage) -> String {
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
    
    static func saveExtractedText(_ text: String) -> (URL, URL) {
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
            
            return (fileURL, debugFileURL)
        } catch {
            print("Failed to save text: \(error.localizedDescription)")
            return (fileURL, debugFileURL) // Return the URLs even if saving failed
        }
    }
    
    static func generateDebugText(_ text: String) -> String {
        // Split text into lines for analysis
        let lines = text.components(separatedBy: .newlines)
        var result = "=== SCREENPLAY DEBUG ANALYSIS ===\n\n"
        
        // Add raw line debug output
        result += "=== RAW LINE ANALYSIS ===\n"
        // Show the first 50 lines with line numbers and exact content
        for (index, line) in lines.prefix(50).enumerated() {
            let lineWithWhitespace = line.replacingOccurrences(of: " ", with: "·")
            result += "Line \(index+1): '\(lineWithWhitespace)'\n"
        }
        result += "\n=== STRUCTURAL ANALYSIS ===\n\n"
        
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