import Foundation

struct SetupPolicy: Decodable, Sendable {
    let steps: [[String]]
    let completed: [[String]]

    static let shared: SetupPolicy = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("resources/setup-policy.json"),
              let data = try? Data(contentsOf: url),
              let policy = try? JSONDecoder().decode(SetupPolicy.self, from: data) else { return SetupPolicy(steps: [], completed: []) }
        return policy
    }()

    func allows(_ index: Int, facts: [String: Bool]) -> Bool {
        steps.indices.contains(index) && steps[index].allSatisfy { facts[$0] == true }
    }
    func isComplete(_ index: Int, facts: [String: Bool]) -> Bool {
        completed.indices.contains(index) && !completed[index].isEmpty && completed[index].allSatisfy { facts[$0] == true }
    }
}
