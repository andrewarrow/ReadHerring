import SwiftUI

struct ProcessingView: View {
    let progress: Float
    
    var body: some View {
        VStack {
            Text("Processing PDF...")
                .font(.headline)
                .padding(.bottom, 8)
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(height: 20)
            
            Text("\(Int(progress * 100))%")
                .font(.subheadline)
                .padding(.top, 8)
        }
        .padding()
    }
}