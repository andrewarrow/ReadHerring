import SwiftUI
import UIKit

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("ReadHerring")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            Text("Download voices in iOS Settings")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Accessibility > Spoken Content >")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)

            Text("Voices > English > Voice")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)

            
            ScrollView(.horizontal, showsIndicators: true) {
                Image("voices")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
                    .padding(.horizontal)
            }
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Text("Swipe left to right")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                openSettings()
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("Open Settings")
                }
                .frame(minWidth: 200)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.bottom, 12)
            
            Button(action: {
                showOnboarding = false
            }) {
                Text("Continue to Voice Selection")
                    .frame(minWidth: 200)
                    .padding()
                    .background(Color.secondary.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
            }
            .padding(.bottom, 40)
        }
        .onAppear()
    }
    
    func openSettings() {
        if let url = URL(string: "App-Prefs:root=ACCESSIBILITY&path=SPEECH") {
           UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}