import SwiftUI

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