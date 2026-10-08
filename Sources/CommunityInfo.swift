import SwiftUI

struct CommunityInfo: Decodable {
    struct Project: Decodable, Identifiable {
        let name: String
        let role: String
        let url: URL
        let contributorsURL: URL
        var id: String { name }
    }
    let title: String
    let mission: String
    let credit: String
    let tooltip: String
    struct SupportLink: Decodable, Identifiable {
        let project: String
        let platform: String
        let url: URL
        var id: String { url.absoluteString }
    }
    let supportTitle: String
    let supportDetail: String
    let supportLinks: [SupportLink]
    let projects: [Project]
    static let shared: CommunityInfo? = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("resources/community.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CommunityInfo.self, from: data)
    }()
}

struct CommunityView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(CommunityInfo.shared?.title ?? "Community & support").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let info = CommunityInfo.shared {
                        Text(info.mission).font(.headline)
                        Text(info.credit)
                        Text(info.supportTitle).font(.title3.bold())
                        Text(info.supportDetail)
                        Link("Support the launcher on Ko-fi", destination: URL(string: "https://ko-fi.com/ricklemore")!)
                        ForEach(info.supportLinks) { support in
                            Link("\(support.project) · \(support.platform)", destination: support.url)
                        }
                        Link("Full community credits", destination: URL(string: "https://github.com/\(ProductInfo.shared.repository)/blob/main/docs/community.md")!)
                        Text("Engines, mods and tools").font(.title3.bold())
                        Text("The links below lead to the projects and their contributors or team pages. Upstream credits also acknowledge their libraries and earlier work.").font(.caption).foregroundStyle(.secondary)
                        ForEach(info.projects) { project in
                            VStack(alignment: .leading, spacing: 4) {
                                Link(project.name, destination: project.url).font(.headline)
                                Text(project.role).font(.caption).foregroundStyle(.secondary)
                                Link("Contributors / team", destination: project.contributorsURL).font(.caption)
                            }
                        }
                        Link("C&C Unix Launcher contributors", destination: URL(string: "https://github.com/\(ProductInfo.shared.repository)/graphs/contributors")!)
                    } else { Text("Bundled community credits unavailable.") }
                }.frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            }
        }.padding(26).frame(width: 680, height: 650).preferredColorScheme(.dark)
    }
}
