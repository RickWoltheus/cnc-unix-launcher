import SwiftUI

struct OnlineCopy: Decodable {
    struct Family: Decodable {
        let title: String
        let steps: [String]
        let hosting: String
        let source: URL
    }
    let title: String
    let description: String
    let openra: Family
    let generals: Family
    let prepareLabel: String
    let hostingLabel: String
    let resultNote: String
    static let shared: OnlineCopy? = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("resources/online.json"), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(OnlineCopy.self, from: data)
    }()
}

struct OnlineSetupView: View {
    @ObservedObject var model: LauncherModel
    @State private var hosting = false
    private var openra: Bool { model.game.isClassic || model.selectedModInfo?.native == true }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let copy = OnlineCopy.shared {
                let family = openra ? copy.openra : copy.generals
                Text(copy.title + " · " + model.activeTitle).font(.title2.bold())
                Text(copy.description).font(.callout).fixedSize(horizontal: false, vertical: true)
                Text(family.title).font(.headline).foregroundStyle(model.game.color)
                ForEach(Array(family.steps.enumerated()), id: \.offset) { index, step in
                    Text("\(index + 1). \(step)").font(.callout).fixedSize(horizontal: false, vertical: true)
                }
                Text(family.hosting).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if openra { Toggle(copy.hostingLabel, isOn: $hosting).font(.callout) }
                Button(copy.prepareLabel) { model.prepareOnline(hosting: openra && hosting) }
                    .buttonStyle(.borderedProminent).disabled(!model.canEnterStep(3) || model.activeNeedsInstall)
                Text(model.status).font(.caption).fixedSize(horizontal: false, vertical: true)
                Text(copy.resultNote).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Link("Engine multiplayer instructions", destination: family.source).font(.caption)
            }
        }.padding(28).frame(width: 600).preferredColorScheme(.dark).tint(model.game.color)
    }
}
