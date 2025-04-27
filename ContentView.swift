import SwiftUI
import PDFKit
import Vision
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedURL: URL?
    @State private var extractedText: String = ""
    @State private var isProcessing = false
    @State private var progress: Float = 0.0
    
    var body: some View {
        VStack {
            if isProcessing {
                ProgressView(value: progress) {
                    Text("Processing PDF...")
                }
                .padding()
            } else if !extractedText.isEmpty {
                ScrollView {
                    Text(extractedText.prefix(1000))
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Button("Select PDF") {
                    let picker = DocumentPickerViewController { url in
                        self.selectedURL = url
                        self.isProcessing = true
                        self.progress = 0.0
                        
                        Task {
                            await processPDF(url: url)
                        }
                    }
                    
                    let scenes = UIApplication.shared.connectedScenes
                    let windowScene = scenes.first as? UIWindowScene
                    let window = windowScene?.windows.first
                    window?.rootViewController?.present(picker, animated: true)
                }
                .padding()
            }
        }
    }
    
    func processPDF(url: URL) async {
        // Start accessing security-scoped resource if needed
        let securitySuccess = url.startAccessingSecurityScopedResource()
        defer {
            if securitySuccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Create a local file URL in the app's documents directory
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = url.lastPathComponent
        let localURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            if fileManager.fileExists(atPath: localURL.path) {
                try fileManager.removeItem(at: localURL)
            }
            try fileManager.copyItem(at: url, to: localURL)
        } catch {
            await MainActor.run {
                isProcessing = false
                extractedText = "Failed to copy PDF: \(error.localizedDescription)"
            }
            return
        }
        
        guard let pdf = PDFDocument(url: localURL) else {
            await MainActor.run {
                isProcessing = false
                extractedText = "Failed to load PDF"
            }
            return
        }
        
        let pageCount = pdf.pageCount
        var fullText = ""
        
        for i in 0..<pageCount {
            autoreleasepool {
                if let page = pdf.page(at: i) {
                    let pageText = page.string ?? ""
                    
                    if !pageText.isEmpty {
                        fullText += pageText + "\n"
                    } else {
                        // Use OCR for this page
                        let pageImage = page.thumbnail(of: CGSize(width: 1024, height: 1024), for: .mediaBox)
                        if let cgImage = pageImage.cgImage {
                            let ocrText = performOCR(on: pageImage)
                            fullText += ocrText + "\n"
                        }
                    }
                }
                
                Task { @MainActor in
                    progress = Float(i + 1) / Float(pageCount)
                }
            }
        }
        
        await MainActor.run {
            isProcessing = false
            extractedText = fullText
        }
    }
    
    func performOCR(on image: UIImage) -> String {
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
}

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