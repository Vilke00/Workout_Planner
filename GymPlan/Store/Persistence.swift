import Foundation

enum Persistence {
    static var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func url(_ name: String) -> URL { directory.appendingPathComponent(name) }

    static func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: url(name).path)
    }

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        let fileURL = url(name)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        do {
            return try makeDecoder().decode(T.self, from: data)
        } catch {
            // Keep a copy of the unreadable file instead of silently losing it.
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = url("\(name).unreadable-\(stamp)")
            try? FileManager.default.copyItem(at: fileURL, to: backup)
            print("Persistence: could not decode \(name): \(error)")
            return nil
        }
    }

    static func save<T: Encodable>(_ value: T, to name: String) {
        do {
            let data = try makeEncoder().encode(value)
            try data.write(to: url(name), options: .atomic)
        } catch {
            print("Persistence: could not save \(name): \(error)")
        }
    }

    static func remove(_ name: String) {
        try? FileManager.default.removeItem(at: url(name))
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
