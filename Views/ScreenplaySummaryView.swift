import SwiftUI
import UIKit

// Using BetterScriptView.swift components

struct ScreenplaySummaryView: View {
    let summary: ScreenplaySummary
    let saveAction: (String) -> Void
    @State private var showingReadAlongView = false
    
    // Function to get the PDF URL from available locations
    private func getDefaultPDFURL() -> URL {
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
    
    var body: some View {
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
                    
                    HStack {
                        Button(action: {
                            saveAction(summary.rawText)
                        }) {
                            Text("Save Extracted Text")
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            showingReadAlongView = true
                        }) {
                            Text("Ready to Read")
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.green)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top, 10)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fullScreenCover(isPresented: $showingReadAlongView) {
            // Show the BetterScriptView with its default screenplay
            ScriptParserView()
        }
    }
}