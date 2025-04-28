import SwiftUI
import UIKit

struct DocumentPickerUI: UIViewControllerRepresentable {
    var onDocumentPicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Create document picker for PDF files
        let picker = DocumentPickerViewController(didPickDocumentHandler: onDocumentPicked)
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // Nothing to update
    }
}