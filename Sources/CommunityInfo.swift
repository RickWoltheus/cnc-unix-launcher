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
    let donationPolicy: String
    let ledgerDetail: String
    let emptyLedger: String
    let projects: [Project]
    static let shared: CommunityInfo? = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("resources/community.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CommunityInfo.self, from: data)
    }()
}

struct DonationLedger: Decodable {
    struct Donation: Decodable, Identifiable {
        let id: String
        let date: String
        let project: String
        let amount: String
        let currency: String
        let evidenceURL: URL?
    }
    let lastUpdated: String
    let donations: [Donation]
    static let shared: DonationLedger? = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("resources/donations.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(DonationLedger.self, from: data)
    }()
    static var publicURL: URL { URL(string: "https://github.com/\(ProductInfo.shared.repository)/blob/main/docs/community.md")! }
}

struct CommunityView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(CommunityInfo.shared?.title ?? "Community & donations").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let info = CommunityInfo.shared {
                        Text(info.mission).font(.headline)
                        Text(info.credit)
                        Text("Supporting the people behind it").font(.title3.bold())
                        Text(info.donationPolicy)
                        Link("Support the launcher on Ko-fi", destination: URL(string: "https://ko-fi.com/ricklemore")!)
                        if let ledger = DonationLedger.shared {
                            Text("\(ledger.donations.count) onward donations recorded · updated \(ledger.lastUpdated)").font(.headline)
                            Text(info.ledgerDetail).font(.caption).foregroundStyle(.secondary)
                            if ledger.donations.isEmpty { Text(info.emptyLedger) }
                            ForEach(ledger.donations) { donation in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(donation.date) · \(donation.project) · \(donation.amount) \(donation.currency)")
                                    if let url = donation.evidenceURL { Link("Public record", destination: url) }
                                }
                            }
                        } else { Text("Bundled donation ledger unavailable. See the public record below.") }
                        Link("Latest public credits & donation ledger", destination: DonationLedger.publicURL)
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
