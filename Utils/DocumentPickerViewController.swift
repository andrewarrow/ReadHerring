import SwiftUI
import PDFKit
import UniformTypeIdentifiers

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