import Foundation

/// Mirrors the task list into iCloud's key-value store and surfaces remote
/// changes from other devices.
///
/// Requires the app to be signed with the iCloud key-value store
/// entitlement (Signing & Capabilities → iCloud → Key-value storage).
/// Without it the store silently stays device-local, so the app keeps
/// working unchanged.
final class TaskCloudSync {
    struct Envelope: Codable {
        let updatedAt: Date
        let tasks: [TaskItem]
    }

    /// Called on the main queue when another device pushed a new payload.
    var onRemoteChange: ((Envelope) -> Void)?

    private let store = NSUbiquitousKeyValueStore.default
    private let payloadKey = "com.taskmatrix.tasks-payload"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExternalChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        store.synchronize()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func push(tasks: [TaskItem], updatedAt: Date) {
        let envelope = Envelope(updatedAt: updatedAt, tasks: tasks)
        guard let data = try? encoder.encode(envelope) else { return }

        store.set(data, forKey: payloadKey)
        store.synchronize()
    }

    func currentEnvelope() -> Envelope? {
        guard let data = store.data(forKey: payloadKey) else { return nil }
        return try? decoder.decode(Envelope.self, from: data)
    }

    @objc
    private func handleExternalChange(_ notification: Notification) {
        guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
              changedKeys.contains(payloadKey),
              let envelope = currentEnvelope() else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.onRemoteChange?(envelope)
        }
    }
}
