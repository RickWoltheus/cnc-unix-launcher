import SwiftUI
import AppKit

struct SecurityCopy: Decodable {
    let title: String
    let detail: String
    let steam: String
    let mods: String
    let scanLabel: String
    let scanDetail: String
    let privacy: String
    let limits: String
    let installLabel: String
    let updateLabel: String
    let scanCacheLabel: String
    let setupDetail: String
    let scannerURL: URL
    let docsURL: URL
    static let shared: SecurityCopy? = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("resources/security.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SecurityCopy.self, from: data)
    }()
}

struct SecuritySetupView: View {
    @ObservedObject var model: LauncherModel
    @Environment(\.dismiss) private var dismiss
    private var locked: Bool { model.busy || model.gameRunning || model.externalInstallRunning }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(SecurityCopy.shared?.title ?? "Security & downloads").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let copy = SecurityCopy.shared {
                        Text(copy.detail)
                        Text(copy.steam).font(.callout)
                        Text(copy.mods).font(.callout)
                        Divider()
                        Toggle(copy.scanLabel, isOn: $model.scanDownloads).font(.headline)
                            .disabled(locked || (!model.scanDownloads && (model.scannerStatus != "ready" || model.scanDefinitionsStatus != "ready")))
                        Text(copy.scanDetail).font(.callout)
                        Text(copy.privacy).font(.caption).foregroundStyle(.secondary)
                        Text(copy.limits).font(.caption).foregroundStyle(.secondary)
                        Text("ClamAV: \(model.scannerStatus == "ready" ? "installed" : "not found") · Definitions: \(model.scanDefinitionsStatus)").font(.callout.bold())
                        HStack {
                            Button(copy.installLabel) { model.openSecurityTask("security-tools") }.disabled(locked)
                            Button(copy.updateLabel) { model.openSecurityTask("security-update") }.disabled(locked || model.scannerStatus != "ready")
                            Button("Refresh") { model.refresh() }
                        }
                        Text(copy.setupDetail).font(.caption).foregroundStyle(.secondary)
                        Button(copy.scanCacheLabel) { model.scanCachedDownloads() }
                            .disabled(locked || model.scannerStatus != "ready" || model.scanDefinitionsStatus != "ready")
                        Text(model.status).font(.caption)
                        Button("Open local reports") { NSWorkspace.shared.open(model.root.appendingPathComponent("security")) }
                        HStack {
                            Link("ClamAV official downloads", destination: copy.scannerURL)
                            Link("Scanner limits", destination: copy.docsURL)
                        }.font(.caption)
                        Link("Sources and security review", destination: URL(string: "https://github.com/\(ProductInfo.shared.repository)/blob/main/docs/security.md")!).font(.caption)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(26).frame(width: 720, height: 690).preferredColorScheme(.dark).tint(model.game.color)
    }
}
