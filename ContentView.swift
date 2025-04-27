import SwiftUI
import PDFKit
import Vision
import UniformTypeIdentifiers
import UIKit
import Combine
import AVFoundation
import Foundation

// Model for Cast
// struct CastImage moved to Models/CastImage.swift

// struct CastFilter moved to Models/CastFilter.swift

// struct CastView moved to Views/CastView.swift

// struct FilterOptionView moved to Views/FilterOptionView.swift

// struct CastImageView moved to Views/CastImageView.swift

// struct VoicesViewWrapper moved to Views/VoicesViewWrapper.swift

// struct VoiceRowView moved to Views/VoiceRowView.swift

// Main ContentView
struct ContentView: View {
    @State private var selectedURL: URL?
    @State private var extractedText: String = ""
    @State private var isProcessing = false
    @State private var progress: Float = 0.0
    @State private var screenplaySummary: ScreenplaySummary?
    @State private var activeView: String = "onboarding" // "onboarding", "voices", "cast", "readalong", or "main"
    // Properties and methods moved to CastImage.swift
    // Properties moved to CastFilter.swift
    
    var body: some View {
        ZStack {
            if activeView == "onboarding" {
                OnboardingView(showOnboarding: Binding(
                    get: { true },
                    set: { _ in 
                        self.activeView = "voices"
                    }
                ))
                .transition(.opacity)
            } else if activeView == "voices" {
                VoicesViewWrapper(moveToNextScreen: {
                    self.activeView = "readalong" // Go directly to ReadAlong instead of cast
                })
                .transition(.opacity)
            } else if activeView == "cast" {
                CastView(isPresented: Binding(
                    get: { true },
                    set: { _ in
                        self.activeView = "main"
                    }
                ))
                .transition(.opacity)
            } else if activeView == "readalong" {
                ReadAlongView()
                .transition(.opacity)
            } else {
                VStack {
                    if isProcessing {
                        ProcessingView(progress: progress)
                    } else if let summary = screenplaySummary {
                        ScreenplaySummaryView(summary: summary, saveAction: saveExtractedText)
                    } else {
                        FileSelectionView(
                            selectPDFAction: {
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
                            },
                            showOnboardingAction: {
                                self.activeView = "onboarding"
                            }
                        )
                    }
                }
                .transition(.opacity)
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
            // Update progress at the beginning of each iteration
            await MainActor.run {
                progress = Float(i) / Float(pageCount)
            }
            
            autoreleasepool {
                if let page = pdf.page(at: i) {
                    let pageText = page.string ?? ""
                    
                    if !pageText.isEmpty {
                        fullText += pageText + "\n"
                    } else {
                        // Use OCR for this page
                        let pageImage = page.thumbnail(of: CGSize(width: 1024, height: 1024), for: .mediaBox)
                        if pageImage.cgImage != nil {
                            let ocrText = PDFProcessor.performOCR(on: pageImage)
                            fullText += ocrText + "\n"
                        }
                    }
                }
            }
            
            // Small delay to allow UI updates
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        // Set progress to 100% at the end
        await MainActor.run {
            progress = 1.0
        }
        
        // Parse screenplay structure
        let summary = ScreenplayParser.parseScreenplay(text: fullText)
        
        await MainActor.run {
            isProcessing = false
            extractedText = fullText
            screenplaySummary = summary
        }
    }
    
    func saveExtractedText(_ text: String) {
        let (fileURL, debugFileURL) = PDFProcessor.saveExtractedText(text)
        
        // Share both files
        let activityVC = UIActivityViewController(
            activityItems: [fileURL, debugFileURL],
            applicationActivities: nil
        )
        
        // Present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}

// Extension to make AVSpeechSynthesizer accessible globally
extension AVSpeechSynthesizer {
    static let shared = AVSpeechSynthesizer()
}

// Embedded VoicesViewWrapper moved to Views/VoicesViewWrapper.swift
// VoiceRowView moved to Views/VoiceRowView.swift
