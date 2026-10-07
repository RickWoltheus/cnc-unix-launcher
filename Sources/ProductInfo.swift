import Foundation

struct ProductInfo {
    let name: String
    let version: String
    let repository: String
    let macArchive: String
    let linuxArchive: String
    let executable: String

    static let shared: ProductInfo = {
        let url = Bundle.main.resourceURL!.appendingPathComponent("manifests/product.tsv")
        let row = ((try? String(contentsOf: url, encoding: .utf8)) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\t").map(String.init)
        guard row.count == 6 else {
            return ProductInfo(name: "C&C Unix Launcher", version: "0.2.0", repository: "RickWoltheus/cnc-unix-launcher",
                               macArchive: "CnC-Unix-Launcher-macOS-arm64.zip", linuxArchive: "CnC-Unix-Launcher-linux-x86_64.tar.gz", executable: "CnCUnixLauncher")
        }
        return ProductInfo(name: row[0], version: row[1], repository: row[2], macArchive: row[3], linuxArchive: row[4], executable: row[5])
    }()
    var issuesURL: URL { URL(string: "https://github.com/\(repository)/issues")! }
    var releasesAPI: URL { URL(string: "https://api.github.com/repos/\(repository)/releases?per_page=10")! }
    func releaseURL(_ tag: String) -> URL { URL(string: "https://github.com/\(repository)/releases/tag/\(tag)")! }
    func modRequestURL(game: String) -> URL {
        var url = URLComponents(string: "https://github.com/\(repository)/issues/new")!
        url.queryItems = [URLQueryItem(name: "template", value: "mod-request.md"), URLQueryItem(name: "title", value: "Mod request: \(game)")]
        return url.url!
    }
}
