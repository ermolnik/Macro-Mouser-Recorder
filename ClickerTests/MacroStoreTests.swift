import XCTest
@testable import Clicker

final class MacroStoreTests: XCTestCase {
    private var tmpDir: URL!
    private var store: MacroStore!

    override func setUpWithError() throws {
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClickerTests-\(UUID().uuidString)", isDirectory: true)
        store = try MacroStore(rootDirectory: tmpDir)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func test_saveAndLoad_roundTrip() throws {
        let macro = Macro(
            id: UUID(),
            name: "click two times",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            events: [
                .mouseDown(t: 0.0, button: .left, x: 10, y: 20, clickCount: 1),
                .mouseUp(t: 0.1, button: .left, x: 10, y: 20, clickCount: 1)
            ]
        )
        try store.save(macro)
        let loaded = try XCTUnwrap(try store.load(id: macro.id))
        XCTAssertEqual(loaded, macro)
    }

    func test_list_returnsAllSaved() throws {
        let a = Macro.fixture(name: "a")
        let b = Macro.fixture(name: "b")
        try store.save(a)
        try store.save(b)
        let names = try store.list().map(\.name).sorted()
        XCTAssertEqual(names, ["a", "b"])
    }

    func test_delete_removesFile() throws {
        let m = Macro.fixture(name: "to delete")
        try store.save(m)
        try store.delete(id: m.id)
        XCTAssertNil(try store.load(id: m.id))
    }

    func test_corruptFile_isSkippedInList() throws {
        let good = Macro.fixture(name: "good")
        try store.save(good)
        let bad = tmpDir.appendingPathComponent("bad-\(UUID()).json")
        try Data("not json".utf8).write(to: bad)
        let loaded = try store.list()
        XCTAssertEqual(loaded.map(\.name), ["good"])
    }
}

private extension Macro {
    static func fixture(name: String) -> Macro {
        Macro(id: UUID(), name: name, createdAt: Date(), updatedAt: Date(), events: [])
    }
}
