import SwiftUI

struct ScriptParserView: View {
    @State private var screenplayText = """
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

MIKE (20s, software engineer, disheveled) rushes in, coffee
stains on his shirt.

                         MIKE
          I swear I put it in the conference
          room last night!

JESSICA (30s, marketing director, perpetually optimistic)
bounds in carrying a box of promotional swag.

                         JESSICA
          Don't worry! I have backup units.
          Well, they're prototypes from six
          months ago, but they're basically
          the same thing, right?

                         SARAH
                    (horrified)
          The ones that catch fire?

DAVID (40s, CFO, always with a calculator) enters, looking
pale.

                         DAVID
          Speaking of fire, our insurance
          company just called. Apparently,
          they're concerned about our
          "history of combustible
          presentations."

EMILY (20s, PR manager, fashion-forward) struts in while on
the phone.

                         EMILY
                    (into phone)
          No, TechCrunch, we're NOT the
          company that accidentally sent
          10,000 units to a goat farm...
          Okay, maybe we are.
"""
    
    @State private var parsedSections: [ScriptSection] = []
    @State private var currentSectionIndex = 0
    
    var body: some View {
        VStack {
            Text("Script Parser")
                .font(.largeTitle)
                .padding()
            
            if !parsedSections.isEmpty {
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
        var sections: [ScriptSection] = []
        var currentSectionText = ""
        var currentSectionType: SectionType = .narrator
        
        // Split the text into lines for processing
        let lines = text.components(separatedBy: .newlines)
        
        var i = 0
        while i < lines.count {
            let line = lines[i]
            
            // Skip empty lines at the beginning
            if currentSectionText.isEmpty && line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                i += 1
                continue
            }
            
            // Check if this line indicates a character's dialog
            if isCharacterLine(line) {
                // If we were building a narrator section, finish it
                if !currentSectionText.isEmpty && currentSectionType == .narrator {
                    sections.append(ScriptSection(type: .narrator, text: currentSectionText))
                    currentSectionText = ""
                }
                
                // Extract character name
                let characterName = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Collect dialog lines
                var dialogText = characterName + "\n"
                i += 1
                
                // Check if the next line is a parenthetical
                if i < lines.count && isParentheticalLine(lines[i]) {
                    dialogText += lines[i] + "\n"
                    i += 1
                }
                
                // Collect dialog content
                while i < lines.count && !isCharacterLine(lines[i]) && !lines[i].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    dialogText += lines[i] + "\n"
                    i += 1
                }
                
                sections.append(ScriptSection(type: .character, text: dialogText))
                continue // Skip the normal increment
            } else {
                // This is part of the narrator text
                if currentSectionType != .narrator {
                    // Start a new narrator section
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
        }
        
        return sections
    }
    
    private func isCharacterLine(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if the line is a character name (all caps, centered)
        let isCharacter = trimmedLine.count > 0 && 
                          line.contains("         ") && // Multiple spaces indicating centering
                          trimmedLine.range(of: "^[A-Z0-9 ()]+$", options: .regularExpression) != nil
        
        return isCharacter
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