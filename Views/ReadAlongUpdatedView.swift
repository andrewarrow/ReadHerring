import SwiftUI
import PDFKit
import AVFoundation

struct ReadAlongUpdatedView: View {
    var pdfURL: URL
    var scenes: [Scene]
    
    @State private var showingNavigationView = true
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            // Debug info header
            VStack(alignment: .leading, spacing: 4) {
                Text("DEBUG ReadAlongUpdatedView")
                    .font(.headline)
                    .foregroundColor(.red)
                Text("Scenes Count: \(scenes.count)")
                    .foregroundColor(.orange)
                Text("PDF URL: \(pdfURL.lastPathComponent)")
                    .foregroundColor(.orange)
                Text("Navigation View Visible: \(showingNavigationView ? "YES" : "NO")")
                    .foregroundColor(.orange)
            }
            .font(.caption)
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            .padding(.horizontal)
            
            ZStack {
                // Background PDF view - at 50% height to ensure it doesn't take over
                PDFViewWrapper(pdfURL: pdfURL)
                    .frame(height: UIScreen.main.bounds.height * 0.3)
                    .border(Color.blue, width: 2)
            }
            
            // Dialog navigation view (not in ZStack anymore)
            if showingNavigationView {
                ReadAlongNavigationView(scenes: scenes)
                    .border(Color.red, width: 3) // Make it obvious where it is
                    .background(Color.white)
            } else {
                Text("Navigation view is hidden")
                    .font(.headline)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.yellow)
                    .cornerRadius(8)
            }
        }
        .navigationTitle("Read Along")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation {
                        showingNavigationView.toggle()
                    }
                }) {
                    HStack {
                        Text(showingNavigationView ? "Hide Dialog" : "Show Dialog")
                        Image(systemName: showingNavigationView ? "text.book.closed" : "text.book.closed.fill")
                    }
                }
            }
        }
    }
}

struct ReadAlongUpdatedView_Previews: PreviewProvider {
    static var previews: some View {
        // Create sample data
        let scene = Scene(heading: "INT. OFFICE - DAY", description: "The office is busy.", location: "OFFICE", timeOfDay: "DAY")
        scene.addDialog(character: "SARAH", text: "Has anyone seen the demo unit? (horrified) Anyone?")
        scene.addDialog(character: "MIKE", text: "I swear I put it in the conference room last night!")
        
        return NavigationView {
            ReadAlongUpdatedView(
                pdfURL: Bundle.main.url(forResource: "sample", withExtension: "pdf") ?? URL(fileURLWithPath: ""),
                scenes: [scene]
            )
        }
    }
}