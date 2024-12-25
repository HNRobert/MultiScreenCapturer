import SwiftUI

struct SaveSettingsGroup: View {
    @AppStorage("copyToClipboard") private var copyToClipboard = false
    @AppStorage("autoSaveEnabled") private var autoSaveEnabled = false
    @AppStorage("autoSavePath") private var autoSavePath = ""
    
    var body: some View {
        GroupBox("Save Settings") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Copy to Clipboard after Capturing", isOn: $copyToClipboard)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Toggle("Automatically Save to ...", isOn: $autoSaveEnabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if autoSaveEnabled {
                    HStack(spacing: 8) {
                        TextField("Save Path", text: $autoSavePath)
                        Button("Browse") {
                            selectSavePath()
                        }
                        .frame(width: 80)
                    }
                }
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
