import AppKit
import Foundation
import SwiftUI

public enum AppStatus: Equatable {
    case idle
    case recording
    case playing(repeatIndex: Int, totalRepeats: Int?)
}

@MainActor
public final class AppState: ObservableObject {
    @Published public private(set) var status: AppStatus = .idle
    @Published public private(set) var currentEvents: [RecordedEvent] = []
    @Published public private(set) var savedMacros: [Macro] = []
    @Published public var selectedMacroID: UUID?
    @Published public var playbackSpeed: Double = 1.0
    @Published public var playbackRepeats: PlaybackRepeats = .count(1)
    @Published public var playbackInterval: TimeInterval = 0
    @Published public var hasAccessibility: Bool = false

    private let recorder: EventRecorder
    private let player: EventPlayer
    private let store: MacroStore
    private let hotkeys: HotkeyManager
    private var playTask: Task<Void, Never>?
    private var accessibilityPollTimer: Timer?
    private var didBecomeActiveObserver: NSObjectProtocol?

    public init() {
        self.recorder = EventRecorder()
        self.player = EventPlayer(poster: CGEventPoster())
        self.store = try! MacroStore()
        var stopRef: (() -> Void)?
        self.hotkeys = HotkeyManager(onPressed: { stopRef?() })
        stopRef = { [weak self] in Task { @MainActor in self?.requestStop() } }
        self.hotkeys.registerF8()
        refreshAccessibility()
        reloadMacros()
        startAccessibilityObservers()
    }

    deinit {
        accessibilityPollTimer?.invalidate()
        if let token = didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }

    public func refreshAccessibility() {
        let trusted = AccessibilityCheck.isTrusted(prompt: false)
        if hasAccessibility != trusted {
            hasAccessibility = trusted
        }
        updateAccessibilityPolling(trusted: trusted)
    }

    private func startAccessibilityObservers() {
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshAccessibility() }
        }
        updateAccessibilityPolling(trusted: hasAccessibility)
    }

    private func updateAccessibilityPolling(trusted: Bool) {
        if trusted {
            accessibilityPollTimer?.invalidate()
            accessibilityPollTimer = nil
        } else if accessibilityPollTimer == nil {
            let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refreshAccessibility() }
            }
            RunLoop.main.add(timer, forMode: .common)
            accessibilityPollTimer = timer
        }
    }

    public func reloadMacros() {
        savedMacros = (try? store.list()) ?? []
        savedMacros.sort { $0.updatedAt > $1.updatedAt }
    }

    public func startRecording() {
        guard status == .idle, hasAccessibility else { return }
        do {
            try recorder.start()
            status = .recording
        } catch {
            NSLog("recorder start failed: \(error)")
        }
    }

    public func stopRecording() {
        guard status == .recording else { return }
        currentEvents = recorder.stop()
        status = .idle
    }

    public func startPlayback(events: [RecordedEvent]) {
        guard status == .idle, hasAccessibility, !events.isEmpty else { return }
        let repeats = playbackRepeats.normalized
        let total: Int? = { if case .count(let n) = repeats { return n }; return nil }()
        status = .playing(repeatIndex: 1, totalRepeats: total)
        let speed = playbackSpeed
        let interval = playbackInterval
        playTask = Task { [player, weak self] in
            do {
                try await player.play(events: events,
                                      repeats: repeats,
                                      speed: speed,
                                      intervalBetweenRepeats: interval,
                                      onIteration: { idx in
                                          Task { @MainActor in
                                              self?.updatePlayingIndex(idx, total: total)
                                          }
                                      })
            } catch {
                // cancelled — fall through
            }
            await MainActor.run { self?.status = .idle }
        }
    }

    public func updatePlayingIndex(_ idx: Int, total: Int?) {
        if case .playing = status {
            status = .playing(repeatIndex: idx, totalRepeats: total)
        }
    }

    public func requestStop() {
        switch status {
        case .recording: stopRecording()
        case .playing: player.cancel(); playTask?.cancel(); status = .idle
        case .idle: break
        }
    }

    public func saveCurrent(as name: String) {
        guard !currentEvents.isEmpty else { return }
        let now = Date()
        let macro = Macro(id: UUID(), name: name, createdAt: now, updatedAt: now, events: currentEvents)
        try? store.save(macro)
        reloadMacros()
    }

    public func delete(_ macro: Macro) {
        try? store.delete(id: macro.id)
        reloadMacros()
    }
}
