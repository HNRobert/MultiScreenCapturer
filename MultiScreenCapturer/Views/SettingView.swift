import SwiftUI

struct SettingView: View {
    @Binding var isCapturing: Bool
    @Binding var hideWindowBeforeCapture: Bool
    let captureAction: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 20) {
                        CaptureSettingsGroup(hideWindowBeforeCapture: $hideWindowBeforeCapture)
                        SaveSettingsGroup()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(maxHeight: .infinity)
            
            Button(action: captureAction) {
                Text("Capture All Screens")
                    .font(.headline)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
            }
            .disabled(isCapturing)
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(minWidth: 440, maxWidth: .infinity)
        .scrollIndicators(.visible)
    }
}
