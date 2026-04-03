import Foundation

final class HarnessCommandServer {
    private let directoryURL: URL
    private var task: Task<Void, Never>?

    init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    func start(model: AppModel) {
        task?.cancel()
        task = Task {
            let inboxURL = directoryURL.appendingPathComponent("inbox", isDirectory: true)
            let outboxURL = directoryURL.appendingPathComponent("outbox", isDirectory: true)
            try? FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: outboxURL, withIntermediateDirectories: true)

            while !Task.isCancelled {
                let files = (try? FileManager.default.contentsOfDirectory(at: inboxURL, includingPropertiesForKeys: nil)) ?? []
                for fileURL in files where fileURL.pathExtension == "json" {
                    do {
                        let data = try Data(contentsOf: fileURL)
                        let request = try JSONDecoder().decode(HarnessCommandRequest.self, from: data)
                        let response = await model.handleCommand(request)
                        let responseURL = outboxURL.appendingPathComponent("\(request.id).json")
                        let encoded = try JSONEncoder.pretty.encode(response)
                        try encoded.write(to: responseURL)
                        try? FileManager.default.removeItem(at: fileURL)
                    } catch {
                        try? FileManager.default.removeItem(at: fileURL)
                    }
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
