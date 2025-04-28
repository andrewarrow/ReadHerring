import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ScriptParserView()
                .tabItem {
                    Label("Test Parse", systemImage: "doc.text.magnifyingglass")
                }
                .tag(0)
            
            PDFProcessorView()
                .tabItem {
                    Label("Select PDF", systemImage: "doc.text")
                }
                .tag(1)
        }
    }
}