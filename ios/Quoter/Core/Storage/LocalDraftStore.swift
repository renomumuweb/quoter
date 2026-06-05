import Foundation

struct LocalDraftStore {
    private let folderName = "Drafts"

    func save(data: Data, name: String) throws {
        let url = try fileURL(name: name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    func load(name: String) throws -> Data? {
        let url = try fileURL(name: name)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func delete(name: String) throws {
        let url = try fileURL(name: name)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func fileURL(name: String) throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return root.appendingPathComponent(folderName, isDirectory: true).appendingPathComponent(name)
    }
}
