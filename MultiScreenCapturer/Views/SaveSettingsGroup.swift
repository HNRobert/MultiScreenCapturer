import SwiftUI

struct SaveSettingsGroup: View {
    @AppStorage("copyToClipboard") private var copyToClipboard = false
    @AppStorage("autoSaveEnabled") private var autoSaveEnabled = false
    @AppStorage("autoSavePath") private var autoSavePath = ""
    
    var body: some View {
        GroupBox("Save Settings") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Copy Screenshot to Clipboard after Capturing", isOn: $copyToClipboard)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    Toggle(isOn: $autoSaveEnabled) {
                        if autoSaveEnabled {
                            Text("Automatically Save Screenshot to")
                        } else {
                            Text("Automatically Save Screenshot to ... after Capturing")
                        }
                    }.padding(.vertical, 3)
                    .onChange(of: autoSaveEnabled) { _, isEnabled in
                        if isEnabled && autoSavePath.isEmpty {
                            selectSavePath()
                        }
                    }
                    if autoSaveEnabled {
                        TextField("Save Path", text: $autoSavePath)
                            .frame(maxWidth: .infinity)
                        Button("Browse") {
                            selectSavePath()
                        }
                        .frame(width: 80)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func selectSavePath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            autoSavePath = panel.url?.path ?? ""
        }
    }
}
