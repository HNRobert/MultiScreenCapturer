import SwiftUI

public struct CaptureSettingsGroup: View {
    @AppStorage("cornerStyle") private var cornerStyle = ScreenCornerStyle.none
    @AppStorage("screenSpacing") private var screenSpacing: Double = 10
    @AppStorage("enableShadow") private var enableShadow = true
    @AppStorage("resolutionStyle") private var resolutionStyle = ResolutionStyle.highestDPI
    @AppStorage("cornerRadius") private var cornerRadius: Double = 30
    @Binding var hideWindowBeforeCapture: Bool
    
    private var cornerStyleOptions: [ScreenCornerStyle] = [.none, .mainOnly, .builtInOnly, .builtInTopOnly, .all]
    private var resolutionStyleOptions: [ResolutionStyle] = [._1080p, ._2k, ._4k, .highestDPI]
    
    public init(hideWindowBeforeCapture: Binding<Bool>) {
        _hideWindowBeforeCapture = hideWindowBeforeCapture
    }
    
    public var body: some View {
        GroupBox("Capture Settings") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Hide window before capture", isOn: $hideWindowBeforeCapture)
                Toggle("Enable Screen Shadow", isOn: $enableShadow)
                
                HStack {
                    Text("Screen Spacing")
                    TextField("Pixels", value: $screenSpacing, format: .number)
                        .frame(width: 80)
                    Text("px")
                }
                
                Picker("Screen Corners", selection: $cornerStyle) {
                    ForEach(cornerStyleOptions, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                
                if cornerStyle != .none {
                    HStack {
                        Text("Corner Radius")
                        TextField("Pixels", value: $cornerRadius, format: .number)
                            .frame(width: 80)
                        Text("px")
                    }
                }
                
                Picker("Resolution", selection: $resolutionStyle) {
                    ForEach(resolutionStyleOptions, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
    }
}
