import SwiftUI
import PDFKit

struct ReadAlongView: View {
    var pdfURL: URL
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            PDFViewWrapper(pdfURL: pdfURL)
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
                }
        }
    }
}

// Wrapper for UIKit's PDFView
struct PDFViewWrapper: UIViewRepresentable {
    let pdfURL: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.usePageViewController(true)
        pdfView.pageBreakMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        // Enable scrolling with gestures
        pdfView.isUserInteractionEnabled = true
        
        // Load PDF document
        if let document = PDFDocument(url: pdfURL) {
            pdfView.document = document
            // Go to first page
            if let firstPage = document.page(at: 0) {
                pdfView.go(to: firstPage)
            }
        }
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        // Update PDF if URL changes
        if let document = PDFDocument(url: pdfURL) {
            uiView.document = document
        }
    }
}

struct ReadAlongView_Previews: PreviewProvider {
    static var previews: some View {
        // Use a sample PDF path for preview
        ReadAlongView(pdfURL: Bundle.main.url(forResource: "sample", withExtension: "pdf") ?? URL(fileURLWithPath: ""))
    }
}