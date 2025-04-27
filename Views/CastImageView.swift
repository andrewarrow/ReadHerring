import SwiftUI
import UIKit

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