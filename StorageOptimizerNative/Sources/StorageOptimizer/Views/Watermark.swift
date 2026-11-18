import SwiftUI

/// Permanent Hexmorio branding. There is deliberately no setting to hide it.
struct HexmorioWatermark: View {
    static let url = URL(string: "http://hexmorio.com/")!

    var body: some View {
        Link(destination: Self.url) {
            HStack(spacing: 4) {
                Image(systemName: "hexagon.fill")
                Text("hexmorio.com")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .help("Made by Hexmorio - visit hexmorio.com")
        .accessibilityLabel("Hexmorio website")
    }
}
