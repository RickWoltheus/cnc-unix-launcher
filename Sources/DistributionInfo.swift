import SwiftUI

struct MacDistributionInfo: Decodable {
    let title: String
    let detail: String
    let priceNote: String
    let openAnyway: String
    let appleURL: URL
    let helpURL: URL
    let supportURL: URL
    static let shared: MacDistributionInfo? = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("resources/mac-distribution.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(MacDistributionInfo.self, from: data)
    }()
}

struct MacDistributionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let info = MacDistributionInfo.shared {
                Text(info.title).font(.title2.bold())
                Text(info.detail).fixedSize(horizontal: false, vertical: true)
                Text(info.openAnyway).font(.callout).fixedSize(horizontal: false, vertical: true)
                Text(info.priceNote).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Link("Apple’s membership details", destination: info.appleURL)
                    Link("First-launch instructions", destination: info.helpURL)
                }.font(.caption)
                Link("Help fund signing on Ko-fi", destination: info.supportURL)
            } else {
                Text("This preview is not notarized. Use Apple’s first-launch instructions if macOS blocks it.")
            }
        }.padding(28).frame(width: 570).preferredColorScheme(.dark)
    }
}
