import SwiftUI
import UIKit

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