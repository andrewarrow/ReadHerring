import SwiftUI

struct ScreenplaySummaryView: View {
    let summary: ScreenplaySummary
    let saveAction: (String) -> Void
    @State private var showingReadAlongView = false
    
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
                            Text("Read Along")
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
            ReadAlongSimpleView(scenes: summary.scenes)
        }
    }
}