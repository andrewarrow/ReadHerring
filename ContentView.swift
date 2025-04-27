import SwiftUI
import PDFKit
import Vision
import UniformTypeIdentifiers
import UIKit
import Combine
import AVFoundation

// Model for Cast
struct CastImage: Identifiable, Hashable {
    var id = UUID()
    var imageName: String
    var race: String
    var age: String
    var gender: String
    var emotion: String
    
    static func parseFromFolder(folderName: String) -> CastImage? {
        // Format: race_age_gender_emotion
        let components = folderName.split(separator: "_")
        guard components.count == 4 else { return nil }
        
        let race = String(components[0])
        let age = String(components[1])
        let gender = String(components[2])
        let emotion = String(components[3])
        
        return CastImage(
            imageName: folderName,
            race: race,
            age: age,
            gender: gender,
            emotion: emotion
        )
    }
    
    func matchesFilter(filter: CastFilter) -> Bool {
        if filter.gender != "random" && gender != filter.gender {
            return false
        }
        
        if filter.age != "none" && age != filter.age {
            return false
        }
        
        if filter.race != "none" && race != filter.race {
            return false
        }
        
        if filter.emotion != "none" && emotion != filter.emotion {
            return false
        }
        
        return true
    }
}

struct CastFilter: Equatable {
    var gender: String = "M"
    var age: String = "none"
    var race: String = "none"
    var emotion: String = "none"
    
    static let ageOptions = ["none", "1-21", "21-35", "34-50", "49-100"]
    static let raceOptions = ["none", "asian", "white", "latino_hispanic", "middle_eastern", "indian", "black"]
    static let emotionOptions = ["none", "happy", "neutral"]
    static let genderOptions = ["M", "F", "random"]
}

// Cast View
struct CastView: View {
    @State private var filter = CastFilter()
    @State private var allImages: [CastImage] = []
    @State private var filteredImages: [CastImage] = []
    @Binding var isPresented: Bool
    
    init(isPresented: Binding<Bool> = .constant(true)) {
        self._isPresented = isPresented
    }
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    isPresented = false
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                Text("Cast Selection")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Balance the layout
                Text("     ")
                    .padding(.horizontal)
                    .opacity(0)
            }
            .padding(.top)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    FilterOptionView(
                        title: "Gender",
                        options: CastFilter.genderOptions,
                        selectedOption: $filter.gender,
                        onChange: updateFilteredImages
                    )
                    
                    FilterOptionView(
                        title: "Age",
                        options: CastFilter.ageOptions,
                        selectedOption: $filter.age,
                        onChange: updateFilteredImages
                    )
                    
                    FilterOptionView(
                        title: "Race",
                        options: CastFilter.raceOptions,
                        selectedOption: $filter.race,
                        onChange: updateFilteredImages
                    )
                    
                    FilterOptionView(
                        title: "Emotion",
                        options: CastFilter.emotionOptions,
                        selectedOption: $filter.emotion,
                        onChange: updateFilteredImages
                    )
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
            
            Text("\(filteredImages.count) results")
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.bottom, 5)
            
            if filteredImages.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No Matching Images")
                        .font(.headline)
                    
                    Text("Try adjusting your filters")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    // Check if LazyVGrid is available (iOS 14+)
                    if #available(iOS 14.0, *) {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
                        ], spacing: 16) {
                            ForEach(filteredImages) { castImage in
                                CastImageView(castImage: castImage)
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // Fallback for iOS 13 and below
                        VStack(spacing: 16) {
                            ForEach(0..<(filteredImages.count + 1) / 2, id: \.self) { row in
                                HStack(spacing: 16) {
                                    ForEach(0..<2) { col in
                                        let index = row * 2 + col
                                        if index < filteredImages.count {
                                            CastImageView(castImage: filteredImages[index])
                                                .frame(maxWidth: .infinity)
                                        } else {
                                            Spacer().frame(maxWidth: .infinity)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .onAppear {
            loadImages()
        }
    }
    
    private func loadImages() {
        var images: [CastImage] = []
        var loadedCount = 0
        var checkedCount = 0
        
        print("DEBUG: Starting to load cast images...")
        
        // Get list of all cast directories
        let folderPattern = ["asian", "black", "indian", "latino_hispanic", "middle_eastern", "white", "none"]
        let agePattern = ["1-21", "21-35", "34-50", "49-100", "none"]
        let genderPattern = ["M", "F"]
        let emotionPattern = ["happy", "neutral", "none"]
        
        // APPROACH 1: Load from Assets.xcassets/cast
        print("DEBUG: Looking for images in Assets.xcassets/cast")
        
        // Try to load a test image to verify asset catalog is working
        if let testImage = UIImage(named: "AppIcon") {
            print("DEBUG: Successfully loaded test image (AppIcon)")
        } else {
            print("DEBUG: Failed to load test image (AppIcon) - asset catalog may not be accessible")
        }
        
        var foundAnyImages = false
        
        // Construct all possible folder combinations using the naming pattern in Assets.xcassets/cast
        for race in folderPattern {
            for age in agePattern {
                for gender in genderPattern {
                    for emotion in emotionPattern {
                        let folderName = "\(race)_\(age)_\(gender)_\(emotion)"
                        
                        // For each folder, check for 8 images (image_1 through image_8)
                        for i in 1...8 {
                            checkedCount += 1
                            
                            // Try different image naming patterns that might be in the asset catalog
                            let imageNames = [
                                "cast/\(folderName)/image_\(i)",  // With full path (primary format)
                                "\(folderName)/image_\(i)",        // Just the category folder
                                "image_\(i)"                      // Direct reference (least likely)
                            ]
                            
                            var foundImage = false
                            
                            // Try each naming pattern
                            for imageName in imageNames {
                                if let _ = UIImage(named: imageName) {
                                    // Successfully found and loaded the image in the asset catalog
                                    let image = CastImage(
                                        imageName: imageName,
                                        race: race,
                                        age: age,
                                        gender: gender,
                                        emotion: emotion
                                    )
                                    images.append(image)
                                    loadedCount += 1
                                    foundImage = true
                                    foundAnyImages = true
                                    
                                    if loadedCount <= 3 {
                                        // Log only the first few successful loads
                                        print("DEBUG: Successfully loaded image from asset catalog: \(imageName)")
                                    }
                                    
                                    break // Found this image, move to next
                                }
                            }
                            
                            // Log unsuccessful attempts sparingly
                            if !foundImage && checkedCount <= 10 {
                                print("DEBUG: Could not find image for \(folderName)/image_\(i)")
                            }
                        }
                    }
                }
            }
        }
        
        // APPROACH 2: Fall back to demo data if no images found
        if !foundAnyImages {
            print("DEBUG: No images found in asset catalog, using fallback demo data")
            
            // Sample data representing a subset of possible combinations
            let sampleData = [
                ("asian", "21-35", "M", "happy"),
                ("white", "21-35", "M", "neutral"),
                ("black", "21-35", "M", "happy"),
                ("latino_hispanic", "21-35", "M", "neutral"),
                ("indian", "21-35", "M", "happy"),
                ("middle_eastern", "21-35", "M", "neutral"),
                ("white", "1-21", "M", "happy"),
                ("white", "34-50", "M", "neutral"),
                ("asian", "1-21", "F", "happy"),
                ("white", "21-35", "F", "neutral"),
                ("black", "34-50", "F", "happy"),
                ("latino_hispanic", "49-100", "F", "neutral")
            ]
            
            // Add placeholder images with the sample data
            for (race, age, gender, emotion) in sampleData {
                // Create a more descriptive placeholder name
                let placeholderName = "\(race)_\(age)_\(gender)_\(emotion)"
                print("DEBUG: Adding placeholder for: \(placeholderName)")
                
                let image = CastImage(
                    imageName: "AppIcon", // Use AppIcon as a placeholder
                    race: race,
                    age: age,
                    gender: gender,
                    emotion: emotion
                )
                images.append(image)
                loadedCount += 1
                
                // Add a few more variants for each category to show filtering more clearly
                for i in 1...2 {
                    images.append(CastImage(
                        imageName: "AppIcon",
                        race: race,
                        age: age, 
                        gender: gender,
                        emotion: emotion
                    ))
                    loadedCount += 1
                }
            }
        }
        
        print("DEBUG: Finished loading images. Total loaded: \(loadedCount), Total checked: \(checkedCount)")
        self.allImages = images
        updateFilteredImages()
    }
    
    private func updateFilteredImages() {
        print("DEBUG: Filtering images with: gender=\(filter.gender), age=\(filter.age), race=\(filter.race), emotion=\(filter.emotion)")
        print("DEBUG: Total images before filtering: \(allImages.count)")
        
        self.filteredImages = allImages.filter { $0.matchesFilter(filter: filter) }
        
        print("DEBUG: Total images after filtering: \(filteredImages.count)")
        
        if filteredImages.isEmpty && !allImages.isEmpty {
            print("DEBUG: No images match the current filter, but there are \(allImages.count) images available")
            
            // Print some sample images from allImages for debugging
            for (index, image) in allImages.prefix(3).enumerated() {
                print("DEBUG: Sample image \(index): \(image.imageName), race=\(image.race), age=\(image.age), gender=\(image.gender), emotion=\(image.emotion)")
            }
        }
    }
}

struct FilterOptionView: View {
    let title: String
    let options: [String]
    @Binding var selectedOption: String
    let onChange: () -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 5)
            
            Picker(title, selection: Binding(
                get: { self.selectedOption },
                set: { 
                    self.selectedOption = $0
                    self.onChange()
                }
            )) {
                ForEach(options, id: \.self) { option in
                    Text(option.replacingOccurrences(of: "_", with: " ").capitalized)
                        .tag(option)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(minWidth: 120)
            .padding(8)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)
        }
    }
}

struct CastImageView: View {
    let castImage: CastImage
    @State private var imageLoaded = false
    @State private var image: UIImage? = nil
    @State private var uniqueIdentifier = UUID().uuidString.prefix(4)
    
    var body: some View {
        VStack {
            ZStack {
                // If the image loads successfully or it's a placeholder AppIcon
                if let uiImage = image {
                    // If it's a placeholder AppIcon, add a demographic label overlay
                    if castImage.imageName == "AppIcon" {
                        ZStack {
                            // Base image
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 150, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .shadow(radius: 3)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                )
                                
                            // Demographics overlay
                            VStack {
                                Spacer()
                                HStack {
                                    Text("\(castImage.race.prefix(1).uppercased())")
                                        .font(.system(size: 14, weight: .bold))
                                        .padding(4)
                                        .background(Color.gray.opacity(0.7))
                                        .foregroundColor(.white)
                                        .clipShape(Circle())
                                    
                                    Text("\(castImage.age)")
                                        .font(.system(size: 10))
                                        .padding(4)
                                        .background(Color.blue.opacity(0.7))
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                    
                                    Text("\(castImage.gender)")
                                        .font(.system(size: 10))
                                        .padding(4)
                                        .background(castImage.gender == "M" ? Color.green.opacity(0.7) : Color.purple.opacity(0.7))
                                        .foregroundColor(.white)
                                        .clipShape(Circle())
                                    
                                    Text("\(castImage.emotion.prefix(1).uppercased())")
                                        .font(.system(size: 10))
                                        .padding(4)
                                        .background(castImage.emotion == "happy" ? Color.yellow.opacity(0.7) : Color.orange.opacity(0.7))
                                        .foregroundColor(.white)
                                        .clipShape(Circle())
                                    
                                    // Add a unique identifier to distinguish duplicates
                                    Text("\(uniqueIdentifier)")
                                        .font(.system(size: 8))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(.horizontal, 8)
                                .padding(.bottom, 8)
                            }
                        }
                    } else {
                        // Regular image (not placeholder)
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(radius: 3)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            )
                    }
                } else {
                    // Fallback if image doesn't load
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            VStack {
                                Image(systemName: "person.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                
                                if castImage.imageName != "AppIcon" {
                                    Text(String(castImage.imageName.suffix(15)))
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                }
                            }
                        )
                }
            }
            .onAppear {
                loadImage()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(castImage.race.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack {
                    Text(castImage.age)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(castImage.emotion.capitalized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 5)
        }
        .padding(.bottom, 5)
    }
    
    private func loadImage() {
        if castImage.imageName == "AppIcon" {
            // If using the AppIcon placeholder
            self.image = UIImage(named: "AppIcon")
            self.imageLoaded = true
        } else if castImage.imageName.contains("/") {
            // Try loading from a file path
            // First try with the path as is
            if let uiImage = UIImage(contentsOfFile: castImage.imageName) {
                self.image = uiImage
                self.imageLoaded = true
                print("DEBUG: Successfully loaded image from file path: \(castImage.imageName)")
            } 
            // Then try with UIImage(named:) which searches in asset catalogs
            else if let uiImage = UIImage(named: castImage.imageName) {
                self.image = uiImage
                self.imageLoaded = true
                print("DEBUG: Successfully loaded image from asset catalog: \(castImage.imageName)")
            }
            // If that fails, try adding "cast/" prefix if not already present
            else if !castImage.imageName.starts(with: "cast/"), let uiImage = UIImage(named: "cast/\(castImage.imageName)") {
                self.image = uiImage
                self.imageLoaded = true
                print("DEBUG: Successfully loaded image with cast/ prefix: cast/\(castImage.imageName)")
            }
            else {
                print("DEBUG: Failed to load image from file path: \(castImage.imageName)")
                self.imageLoaded = false
            }
        } else {
            // Try loading from asset catalog
            if let uiImage = UIImage(named: castImage.imageName) {
                self.image = uiImage
                self.imageLoaded = true
                print("DEBUG: Successfully loaded image from asset catalog: \(castImage.imageName)")
            } else {
                print("DEBUG: Failed to load image from asset catalog: \(castImage.imageName)")
                self.imageLoaded = false
            }
        }
    }
}

// Main ContentView
struct ContentView: View {
    @State private var selectedURL: URL?
    @State private var extractedText: String = ""
    @State private var isProcessing = false
    @State private var progress: Float = 0.0
    @State private var screenplaySummary: ScreenplaySummary?
    @State private var activeView: String = "onboarding" // "onboarding", "voices", "cast", or "main"
    
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
                    self.activeView = "cast"
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
                        if let cgImage = pageImage.cgImage {
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

// Wrapper for VoicesView to handle navigation
struct VoicesViewWrapper: View {
    var moveToNextScreen: () -> Void
    @State private var voices: [AVSpeechSynthesisVoice] = []
    @State private var selectedVoice: AVSpeechSynthesisVoice?
    @State private var isPlaying: String? = nil
    
    private let sampleText = "To be or not to be, that is the question."
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    moveToNextScreen()
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                Text("Voice Selection")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Balance the layout
                Text("     ")
                    .padding(.horizontal)
                    .opacity(0)
            }
            .padding(.top)
            
            Text("Select a voice to use for character readings")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom)
            
            List {
                ForEach(voices, id: \.identifier) { voice in
                    VoiceRowView(
                        voice: voice,
                        isPlaying: isPlaying == voice.identifier,
                        sampleText: sampleText,
                        onPlay: {
                            playVoice(voice)
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedVoice = voice
                    }
                    .background(selectedVoice?.identifier == voice.identifier ? Color.blue.opacity(0.1) : Color.clear)
                }
            }
            
            Button(action: {
                // Save selected voice and continue to cast view
                moveToNextScreen()
            }) {
                Text("Continue to Cast Selection")
                    .frame(minWidth: 200)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.bottom, 20)
            .disabled(selectedVoice == nil)
            .opacity(selectedVoice == nil ? 0.5 : 1.0)
        }
        .onAppear {
            loadVoices()
        }
    }
    
    private func loadVoices() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        voices = allVoices.filter { $0.language.starts(with: "en") }
        
        print("Loaded \(voices.count) English voices")
        for voice in voices {
            print("Voice: \(voice.name), ID: \(voice.identifier), Quality: \(voice.quality.rawValue)")
        }
    }
    
    private func playVoice(_ voice: AVSpeechSynthesisVoice) {
        // Stop any currently playing speech
        if isPlaying != nil {
            AVSpeechSynthesizer.shared.stopSpeaking(at: .immediate)
        }
        
        // Set the voice as playing
        isPlaying = voice.identifier
        
        // Create and configure utterance
        let utterance = AVSpeechUtterance(string: sampleText)
        utterance.voice = voice
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // Start speaking
        AVSpeechSynthesizer.shared.speak(utterance)
        
        // Set timer to stop playing status after a few seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if self.isPlaying == voice.identifier {
                self.isPlaying = nil
            }
        }
    }
}

// Extension to make AVSpeechSynthesizer accessible globally
extension AVSpeechSynthesizer {
    static let shared = AVSpeechSynthesizer()
}

struct VoiceRowView: View {
    let voice: AVSpeechSynthesisVoice
    let isPlaying: Bool
    let sampleText: String
    let onPlay: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(voice.name)
                    .font(.headline)
                
                Text(voice.language)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if voice.quality == .enhanced {
                    Text("Premium Voice")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .foregroundColor(isPlaying ? .red : .blue)
            }
        }
        .padding(.vertical, 4)
    }
}