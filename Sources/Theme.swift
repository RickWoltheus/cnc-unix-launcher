import SwiftUI

enum CommandTheme {
    static let background = Color(red: 0.055, green: 0.065, blue: 0.075)
    static let panel = Color(red: 0.10, green: 0.12, blue: 0.13)
    static let amber = Color(red: 0.95, green: 0.67, blue: 0.24)
    static let muted = Color(red: 0.57, green: 0.62, blue: 0.62)
    static let line = Color.white.opacity(0.10)
}

struct CommandBackground: View {
    @Environment(\.gameAccent) private var accent
    var body: some View {
        ZStack {
            CommandTheme.background
            LinearGradient(colors: [accent.opacity(0.15), .clear, Color.black.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, size in
                var path = Path()
                for x in stride(from: 0.0, to: size.width, by: 44) {
                    path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: 0.0, to: size.height, by: 44) {
                    path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(.white.opacity(0.025)), lineWidth: 1)
            }
        }.ignoresSafeArea()
    }
}

struct CommandButton: ButtonStyle {
    @Environment(\.gameAccent) private var accent
    var secondary = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold)).tracking(1)
            .padding(.horizontal, 24).padding(.vertical, 15)
            .foregroundStyle(secondary ? Color.white : Color.black)
            .background(secondary ? CommandTheme.panel : accent)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(secondary ? CommandTheme.line : accent, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .opacity(!isEnabled ? 0.45 : (configuration.isPressed ? 0.7 : 1))
    }
}

struct BriefingTitle: View {
    @Environment(\.gameAccent) private var accent
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow.uppercased()).font(.system(size: 11, weight: .bold)).tracking(2.5).foregroundStyle(accent)
            Text(title).font(.system(size: 36, weight: .black)).tracking(-0.5)
            Text(subtitle).font(.system(size: 14)).foregroundStyle(CommandTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ReadinessRow: View {
    @Environment(\.gameAccent) private var accent
    let title: String
    let detail: String
    let ready: Bool
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: ready ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 22)).foregroundStyle(ready ? Color.green : accent)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(CommandTheme.muted)
            }
            Spacer()
            Text(ready ? "READY" : "TO INSTALL").font(.system(size: 10, weight: .bold)).tracking(1.5)
                .foregroundStyle(ready ? Color.green : CommandTheme.muted)
        }.padding(20).background(CommandTheme.panel).clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

struct ModArtwork: View {
    @Environment(\.gameAccent) private var accent
    let mod: ModInfo
    var body: some View {
        AsyncImage(url: mod.imageURL) { phase in
            if let image = phase.image { image.resizable().scaledToFit().background(Color.black.opacity(0.35)) }
            else {
                ZStack {
                    LinearGradient(colors: [CommandTheme.panel, accent.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "shield.lefthalf.filled").font(.system(size: 38)).foregroundStyle(accent.opacity(0.6))
                }
            }
        }
    }
}

struct GameLogo: View {
    let game: GameInfo
    var width: CGFloat = 166
    var height: CGFloat = 70
    var fit = false
    var body: some View {
        AsyncImage(url: game.logoURL) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: fit ? .fit : .fill)
            } else {
                Text(game.emblem).font(.system(size: 28, weight: .black)).foregroundStyle(game.color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.frame(width: width, height: height).clipped().accessibilityLabel(game.title)
    }
}
