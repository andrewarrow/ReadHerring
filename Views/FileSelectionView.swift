import SwiftUI

struct FileSelectionView: View {
    let selectPDFAction: () -> Void
    let showOnboardingAction: () -> Void
    
    var body: some View {
        VStack {
            Button("Select PDF", action: selectPDFAction)
                .padding()
            
            Button(action: showOnboardingAction) {
                Text("Show Setup Instructions")
                    .font(.footnote)
                    .foregroundColor(.blue)
            }
            .padding(.top, 8)
        }
    }
}