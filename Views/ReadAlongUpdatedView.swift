import SwiftUI
import PDFKit
import AVFoundation

struct ReadAlongUpdatedView: View {
    var pdfURL: URL
    var scenes: [Scene]
    
    @State private var showingNavigationView = true
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // Background PDF view
            PDFViewWrapper(pdfURL: pdfURL)
                .edgesIgnoringSafeArea(.bottom)
            
            // Dialog navigation overlay
            if showingNavigationView {
                ReadAlongNavigationView(scenes: scenes)
                    .transition(.move(edge: .bottom))
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
                    Image(systemName: showingNavigationView ? "text.book.closed" : "text.book.closed.fill")
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