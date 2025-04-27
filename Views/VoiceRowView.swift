import SwiftUI
import AVFoundation

struct VoiceRowView: View {
    let voice: AVSpeechSynthesisVoice
    let isPlaying: Bool
    let sampleText: String
    let onPlay: () -> Void
    
    var body: some View {
        HStack {
            // Voice information - This part is tappable for selection
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
            
            // Play button in its own tap area
            ZStack {
                // Make a larger tap target with background
                Circle()
                    .fill(Color.clear)
                    .frame(width: 60, height: 60)
                
                // The actual button
                Button(action: onPlay) {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)
                        .foregroundColor(isPlaying ? .red : .blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .contentShape(Circle()) // Make the entire circle tappable
            .onTapGesture {
                onPlay()
            }
        }
        .padding(.vertical, 4)
    }
}
