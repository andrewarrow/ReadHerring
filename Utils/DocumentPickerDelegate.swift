import SwiftUI
import UIKit
import UniformTypeIdentifiers

class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let fileHandler: (URL) -> Void
    
    init(fileHandler: @escaping (URL) -> Void) {
        self.fileHandler = fileHandler
        super.init()
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let url = urls.first {
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access security scoped resource")
                return
            }
            
            // Handle the selected file
            fileHandler(url)
            
            // Release the security-scoped resource
            url.stopAccessingSecurityScopedResource()
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("Document picker was cancelled")
    }
}