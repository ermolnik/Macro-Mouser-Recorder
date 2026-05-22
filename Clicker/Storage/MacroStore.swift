import Foundation
import os

public final class MacroStore {
    public enum StoreError: Error { case invalidRoot }

    private let root: URL
    private let fm = FileManager.default
    private let logger = Logger(subsystem: "app.clicker", category: "MacroStore")

    public convenience init() throws {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        let dir = appSupport.appendingPathComponent("Clicker/macros", isDirectory: true)
        try self.init(rootDirectory: dir)
    }

    public init(rootDirectory: URL) throws {
        self.root = rootDirectory
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    public func save(_ macro: Macro) throws {
        let url = fileURL(for: macro.id, name: macro.name)
        try purgeFiles(matchingID: macro.id, except: url)
        let data = try encoder.encode(macro)
        try data.write(to: url, options: .atomic)
    }

    public func load(id: UUID) throws -> Macro? {
        guard let url = try findFile(forID: id) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(Macro.self, from: data)
    }

    public func list() throws -> [Macro] {
        let urls = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        var out: [Macro] = []
        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                out.append(try decoder.decode(Macro.self, from: data))
            } catch {
                logger.warning("Skipping corrupt macro file \(url.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
        return out
    }

    public func delete(id: UUID) throws {
        guard let url = try findFile(forID: id) else { return }
        try fm.removeItem(at: url)
    }

    // MARK: - Private

    private lazy var encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private lazy var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func fileURL(for id: UUID, name: String) -> URL {
        let slug = slugify(name)
        return root.appendingPathComponent("\(slug)-\(id.uuidString).json")
    }

    private func findFile(forID id: UUID) throws -> URL? {
        let urls = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        return urls.first { $0.lastPathComponent.contains(id.uuidString) && $0.pathExtension == "json" }
    }

    private func purgeFiles(matchingID id: UUID, except keep: URL) throws {
        let urls = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        for url in urls where url.lastPathComponent.contains(id.uuidString) && url != keep {
            try fm.removeItem(at: url)
        }
    }

    private func slugify(_ name: String) -> String {
        let lowered = name.lowercased()
        let mapped = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) { return Character(scalar) }
            return "-"
        }
        let collapsed = String(mapped).replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
