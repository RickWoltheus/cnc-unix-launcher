import Foundation

struct RecoveryAdvice: Decodable, Sendable {
    let title: String
    let message: String

    private struct Rule: Decodable, Sendable {
        let containsAny: [String]
        let title: String
        let message: String
    }
    private struct Catalog: Decodable, Sendable {
        let rules: [Rule]
        let fallback: RecoveryAdvice
    }
    private static let catalog: Catalog? = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("resources/recovery-guidance.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Catalog.self, from: data)
    }()

    static func forMessage(_ text: String) -> RecoveryAdvice {
        let message = text.lowercased()
        if let rule = catalog?.rules.first(where: { $0.containsAny.contains(where: message.contains) }) {
            return RecoveryAdvice(title: rule.title, message: rule.message)
        }
        return catalog?.fallback ?? RecoveryAdvice(title: "We could not finish that step", message: "Open Details and retry after checking the error.")
    }
}
