import CoreXLSX
import Foundation
import UniformTypeIdentifiers

struct ImportedExercise: Identifiable {
    let id = UUID()
    var name: String
    var mode: TrackingMode
    var sets: [SetTemplate]
    var restSeconds: Int
    /// "+" in the Superset column: chained with the next exercise.
    var supersetWithNext: Bool = false
    /// Rep range from cells like "8-12", or AMRAP.
    var target: RepTarget = .empty
    /// Rows after an "OR" row: exercises that can be done instead of this one.
    var alternatives: [ImportedExercise] = []
}

struct ImportedRoutine: Identifiable {
    let id = UUID()
    var name: String
    var exercises: [ImportedExercise]
}

enum ImportError: LocalizedError {
    case unreadable
    case empty
    case noExerciseColumn

    var errorDescription: String? {
        switch self {
        case .unreadable: return "The file could not be read. Use an .xlsx or .csv file."
        case .empty: return "The file has no rows."
        case .noExerciseColumn: return "No \"Exercise\" column found in the first row."
        }
    }
}

/// Reads routines from Excel (.xlsx) or CSV.
///
/// Wide format (one row per exercise):
///   Routine | Exercise | Rest | Set 1 | Set 2 | Set 3 ...
///   Upper   | Bench Press | 1:30 | 10x60 | 8x65 | 6x70
///   Upper   | Plank | 60 | 1 min | 1 min
///
/// Long format (one row per set):
///   Routine | Exercise | Reps | Kg | Time (min) | Distance (m) | Rest
enum ImportService {
    static var contentTypes: [UTType] {
        let candidates: [UTType?] = [
            UTType("org.openxmlformats.spreadsheetml.sheet"),
            UTType(filenameExtension: "xlsx"),
            .commaSeparatedText,
            .tabSeparatedText,
            .plainText
        ]
        var result: [UTType] = []
        for case let type? in candidates where !result.contains(type) {
            result.append(type)
        }
        return result
    }

    static func parse(url: URL) throws -> [ImportedRoutine] {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        // Work on a local copy (CoreXLSX needs a normal file path).
        let local = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
        try? FileManager.default.removeItem(at: local)
        try FileManager.default.copyItem(at: url, to: local)
        defer { try? FileManager.default.removeItem(at: local) }

        let rows: [[String]]
        if url.pathExtension.lowercased() == "xlsx" {
            rows = try xlsxRows(local)
        } else {
            rows = try csvRows(local)
        }
        return try routines(from: rows)
    }

    // MARK: - Reading files

    static func xlsxRows(_ url: URL) throws -> [[String]] {
        guard let file = XLSXFile(filepath: url.path) else { throw ImportError.unreadable }
        let sharedStrings = try? file.parseSharedStrings()
        for workbook in try file.parseWorkbooks() {
            for (_, path) in try file.parseWorksheetPathsAndNames(workbook: workbook) {
                let worksheet = try file.parseWorksheet(at: path)
                var result: [[String]] = []
                for row in worksheet.data?.rows ?? [] {
                    var cells: [Int: String] = [:]
                    for cell in row.cells {
                        let column = columnIndex(cell.reference.column.value)
                        var text = cell.value ?? ""
                        if let inline = cell.inlineString?.text {
                            text = inline
                        } else if cell.type == .sharedString,
                           let strings = sharedStrings,
                           let index = Int(text),
                           index >= 0, index < strings.items.count {
                            text = strings.items[index].text ?? ""
                        }
                        cells[column] = text.trimmed
                    }
                    guard let maxColumn = cells.keys.max() else { continue }
                    result.append((0...maxColumn).map { cells[$0] ?? "" })
                }
                return result // first sheet only
            }
        }
        return []
    }

    static func columnIndex(_ letters: String) -> Int {
        var value = 0
        for scalar in letters.uppercased().unicodeScalars {
            let v = Int(scalar.value) - 64
            if v >= 1 && v <= 26 { value = value * 26 + v }
        }
        return max(0, value - 1)
    }

    static func csvRows(_ url: URL) throws -> [[String]] {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .windowsCP1250)
                ?? String(data: data, encoding: .isoLatin1) else {
            throw ImportError.unreadable
        }
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let candidates: [Character] = [";", ",", "\t"]
        let separator = candidates.max { a, b in
            firstLine.filter { $0 == a }.count < firstLine.filter { $0 == b }.count
        } ?? ","

        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = Array(text).makeIterator()
        var pending: Character? = nil

        while let ch = pending ?? iterator.next() {
            pending = nil
            if inQuotes {
                if ch == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" { field.append("\"") } else { inQuotes = false; pending = next }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(ch)
                }
            } else if ch == "\"" {
                inQuotes = true
            } else if ch == separator {
                row.append(field.trimmed)
                field = ""
            } else if ch == "\n" || ch == "\r" || ch == "\r\n" {
                row.append(field.trimmed)
                field = ""
                rows.append(row)
                row = []
            } else {
                field.append(ch)
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field.trimmed)
            rows.append(row)
        }
        return rows
    }

    // MARK: - Rows → routines

    static func routines(from rows: [[String]]) throws -> [ImportedRoutine] {
        let filled = rows.filter { row in row.contains { !$0.trimmed.isEmpty } }
        guard let headerRow = filled.first else { throw ImportError.empty }
        let header = headerRow.map(normalizeHeader)

        func column(_ keys: [String]) -> Int? {
            header.firstIndex { cell in
                keys.contains { key in
                    cell == key || cell.hasPrefix(key + " ") || (key.count >= 4 && cell.hasPrefix(key))
                }
            }
        }

        guard let exerciseColumn = column(["exercise", "vezba", "vjezba", "naziv", "name"]) else {
            throw ImportError.noExerciseColumn
        }
        let routineColumn = column(["routine", "rutina", "day", "dan", "workout", "trening"])
        let restColumn = column(["rest", "odmor", "pauza"])
        let supersetColumn = column(["superset", "ss", "link"])
        let repsColumn = column(["reps", "rep", "ponavljanja", "ponavljanje"])
        let setColumns = header.indices.filter { isSetColumn(header[$0]) }

        var result: [ImportedRoutine] = []
        var currentRoutine = "Imported"
        let body = Array(filled.dropFirst())

        if !setColumns.isEmpty && repsColumn == nil {
            // Wide format. "OR" in the Superset/Link column makes the next row an alternative.
            var nextIsAlternative = false
            for row in body {
                let cell = { (index: Int?) -> String in
                    guard let index, index < row.count else { return "" }
                    return row[index].trimmed
                }
                let routineName = cell(routineColumn)
                if !routineName.isEmpty && routineName != currentRoutine {
                    currentRoutine = routineName
                    nextIsAlternative = false
                }
                let name = cell(exerciseColumn)
                guard !name.isEmpty else { continue }

                var sets: [SetTemplate] = []
                var isTime = false
                var target = RepTarget.empty
                for index in setColumns {
                    let raw = cell(index)
                    guard !raw.isEmpty else { continue }
                    let parsed = parseSetCell(raw)
                    if parsed.isTime { isTime = true }
                    if target.isEmpty { target = parsed.target }
                    sets.append(parsed.set)
                }
                if sets.isEmpty { sets = [SetTemplate()] }
                let link = cell(supersetColumn)
                let exercise = ImportedExercise(name: name,
                                                mode: isTime ? .timeDistance : .weightReps,
                                                sets: sets,
                                                restSeconds: parseRest(cell(restColumn)),
                                                supersetWithNext: isLinked(link),
                                                target: isTime ? RepTarget.empty : target)

                if nextIsAlternative,
                   let r = result.lastIndex(where: { $0.name.caseInsensitiveCompare(currentRoutine) == .orderedSame }),
                   !result[r].exercises.isEmpty {
                    let e = result[r].exercises.count - 1
                    result[r].exercises[e].alternatives.append(exercise)
                    // The link of the last row in an OR group belongs to the whole slot.
                    if exercise.supersetWithNext { result[r].exercises[e].supersetWithNext = true }
                    if result[r].exercises[e].restSeconds == 0 { result[r].exercises[e].restSeconds = exercise.restSeconds }
                } else {
                    append(exercise, routine: currentRoutine, to: &result)
                }
                nextIsAlternative = isOr(link)
            }
        } else {
            // Long format: one row per set; consecutive rows of the same exercise are grouped.
            let weightColumn = column(["kg", "weight", "tezina", "kilaza", "kilogrami"])
            let timeColumn = column(["time", "min", "minutes", "vreme", "vrijeme", "trajanje", "duration"])
            let distanceColumn = column(["distance", "meters", "metres", "meter", "m", "distanca", "metara", "metri"])
            var lastName = ""

            for row in body {
                let cell = { (index: Int?) -> String in
                    guard let index, index < row.count else { return "" }
                    return row[index].trimmed
                }
                let routineName = cell(routineColumn)
                let routineChanged = !routineName.isEmpty && routineName != currentRoutine
                if !routineName.isEmpty { currentRoutine = routineName }
                var name = cell(exerciseColumn)
                if name.isEmpty { name = lastName }   // empty cell = same exercise as above
                guard !name.isEmpty else { continue }

                let minutes = parseMinutes(cell(timeColumn))
                let meters = Fmt.parseDouble(cell(distanceColumn))
                let isTime = minutes > 0 || meters > 0
                let set = SetTemplate(reps: Fmt.parseInt(cell(repsColumn)),
                                      weight: Fmt.parseDouble(cell(weightColumn)),
                                      minutes: minutes,
                                      meters: meters)
                let rest = parseRest(cell(restColumn))

                let sameAsPrevious = !routineChanged && name == lastName
                if sameAsPrevious,
                   let r = result.lastIndex(where: { $0.name.caseInsensitiveCompare(currentRoutine) == .orderedSame }),
                   !result[r].exercises.isEmpty {
                    let e = result[r].exercises.count - 1
                    result[r].exercises[e].sets.append(set)
                    if isTime { result[r].exercises[e].mode = .timeDistance }
                    if result[r].exercises[e].restSeconds == 0 { result[r].exercises[e].restSeconds = rest }
                    if isLinked(cell(supersetColumn)) { result[r].exercises[e].supersetWithNext = true }
                } else {
                    let exercise = ImportedExercise(name: name,
                                                    mode: isTime ? .timeDistance : .weightReps,
                                                    sets: [set],
                                                    restSeconds: rest,
                                                    supersetWithNext: isLinked(cell(supersetColumn)))
                    append(exercise, routine: currentRoutine, to: &result)
                }
                lastName = name
            }
        }
        return result
    }

    private static func append(_ exercise: ImportedExercise, routine: String, to routines: inout [ImportedRoutine]) {
        if let index = routines.lastIndex(where: { $0.name.caseInsensitiveCompare(routine) == .orderedSame }) {
            routines[index].exercises.append(exercise)
        } else {
            routines.append(ImportedRoutine(name: routine, exercises: [exercise]))
        }
    }

    // MARK: - Cell parsing

    static func isLinked(_ raw: String) -> Bool {
        ["+", "yes", "y", "da", "x", "1", "true", "superset", "ss"].contains(raw.lowercased().trimmed)
    }

    static func isOr(_ raw: String) -> Bool {
        ["or", "ili", "|", "/", "alt", "alternative"].contains(raw.lowercased().trimmed)
    }

    /// "8-12" / "8 – 12 x 60" → (8, 12, " x 60")
    static func parseRange(_ text: String) -> (low: Int, high: Int, rest: String)? {
        let chars = Array(text)
        var i = 0
        func skipSpaces() { while i < chars.count, chars[i] == " " { i += 1 } }
        func digits() -> String {
            var out = ""
            while i < chars.count, chars[i].isASCII, chars[i].isNumber { out.append(chars[i]); i += 1 }
            return out
        }
        skipSpaces()
        let a = digits()
        guard !a.isEmpty else { return nil }
        skipSpaces()
        guard i < chars.count, chars[i] == "-" || chars[i] == "–" || chars[i] == "—" else { return nil }
        i += 1
        skipSpaces()
        let b = digits()
        guard !b.isEmpty, let lo = Int(a), let hi = Int(b), lo <= 10_000, hi <= 10_000 else { return nil }
        return (Swift.min(lo, hi), Swift.max(lo, hi), String(chars[i...]))
    }

    static func normalizeHeader(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        let mapped = folded.map { ($0.isLetter || $0.isNumber) ? $0 : Character(" ") }
        return String(mapped).split(separator: " ").joined(separator: " ")
    }

    /// "Set 1", "set1", "S1", "Serija 1" or just "1".
    static func isSetColumn(_ header: String) -> Bool {
        var rest = header
        for prefix in ["serija", "set", "s"] where rest.hasPrefix(prefix) {
            rest = String(rest.dropFirst(prefix.count))
            break
        }
        rest = rest.trimmed
        return !rest.isEmpty && rest.allSatisfy(\.isNumber)
    }

    /// Splits "1 min 30 s" into [(1, "min"), (30, "s")] and "10x60" into [(10, "x"), (60, "")].
    static func tokenize(_ text: String) -> [(value: Double, unit: String)] {
        var result: [(value: Double, unit: String)] = []
        var number = ""
        var unit = ""
        var readingUnit = false

        func flush() {
            if let value = Double(number) { result.append((value, unit)) }
            number = ""
            unit = ""
            readingUnit = false
        }

        for ch in text.lowercased().replacingOccurrences(of: ",", with: ".") {
            if ch.isNumber || ch == "." {
                if readingUnit { flush() }
                number.append(ch)
            } else if ch.isLetter || ch == "'" || ch == "\"" {
                if !number.isEmpty {
                    readingUnit = true
                    unit.append(ch)
                }
            } else if ch == " " {
                if readingUnit { flush() }
            } else {
                // separators like ×, *, @, /
                if !number.isEmpty { flush() }
            }
        }
        flush()
        return result
    }

    static func parseSetCell(_ raw: String) -> (set: SetTemplate, isTime: Bool, target: RepTarget) {
        let text = raw.lowercased().trimmed
        if text.contains(":"), let minutes = parseClock(text) {
            return (SetTemplate(reps: 0, minutes: minutes), true, RepTarget.empty)
        }
        // "AMRAP", "20 AMRAP" (expected reps), "20 AMRAP x 60"
        if text.contains("amrap") || text.contains("failure") || text.contains("otkaz") {
            var cleaned = text
            for word in ["amrap", "to failure", "failure", "do otkaza", "otkaz"] {
                cleaned = cleaned.replacingOccurrences(of: word, with: " ")
            }
            let numbers = tokenize(cleaned).map { $0.value }
            let reps = numbers.first.map { Int(min(max($0, 0), 10_000).rounded()) } ?? 0
            let weight = numbers.count > 1 ? numbers[1] : 0
            return (SetTemplate(reps: reps, weight: weight), false, RepTarget(amrap: true))
        }
        // "8-12" or "8-12x60": a rep range; the plan starts at the bottom of the range.
        if let range = parseRange(text) {
            let weight = tokenize(range.rest).map { $0.value }.first ?? 0
            return (SetTemplate(reps: range.low, weight: weight), false, RepTarget(min: range.low, max: range.high))
        }
        var minutes = 0.0
        var meters = 0.0
        var isTime = false
        for token in tokenize(text) {
            switch token.unit {
            case "min", "mins", "minute", "minutes", "minut", "minuta", "'":
                minutes += token.value; isTime = true
            case "s", "sec", "secs", "second", "seconds", "sek", "\"":
                minutes += token.value / 60; isTime = true
            case "h", "hr", "hrs", "hour", "hours":
                minutes += token.value * 60; isTime = true
            case "m", "meter", "meters", "metre", "metres", "metara", "metri":
                meters += token.value; isTime = true
            case "km":
                meters += token.value * 1000; isTime = true
            default:
                break
            }
        }
        if isTime {
            return (SetTemplate(reps: 0, minutes: minutes, meters: meters), true, RepTarget.empty)
        }
        let numbers = tokenize(text).map { $0.value }
        let reps = numbers.first.map { Int(min(max($0, 0), 10_000).rounded()) } ?? 0
        let weight = numbers.count > 1 ? numbers[1] : 0
        return (SetTemplate(reps: reps, weight: weight), false, RepTarget.empty)
    }

    /// "mm:ss" or "h:mm:ss" → minutes
    static func parseClock(_ text: String) -> Double? {
        let parts = text.split(separator: ":").map { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count >= 2, parts.allSatisfy({ $0 != nil }) else { return nil }
        let values = parts.compactMap { $0 }
        if values.count == 2 { return values[0] + values[1] / 60 }
        return values[0] * 60 + values[1] + values[2] / 60
    }

    static func parseMinutes(_ raw: String) -> Double {
        let text = raw.lowercased().trimmed
        if text.isEmpty { return 0 }
        if text.contains(":"), let minutes = parseClock(text) { return minutes }
        let parsed = parseSetCell(text)
        if parsed.isTime { return parsed.set.minutes }
        return Fmt.parseDouble(text)
    }

    /// "90" → 90 s, "1:30" → 90 s, "2 min" → 120 s, Excel time 0.0625 → 5400 s… (fraction of a day)
    static func parseRest(_ raw: String) -> Int {
        let text = raw.lowercased().replacingOccurrences(of: ",", with: ".").trimmed
        if text.isEmpty || text == "off" || text == "0" || text == "-" { return 0 }
        if text.contains(":"), let minutes = parseClock(text) {
            return clamp(minutes * 60)
        }
        if let value = Double(text) {
            if value > 0 && value < 1 {
                // Excel time cell (fraction of a day). Excel reads "1:30" as 1 h 30 min,
                // which is never a rest time, so treat it as 1 min 30 s.
                let seconds = value * 86_400
                return clamp(seconds >= 1_800 ? value * 1_440 : seconds)
            }
            return clamp(value)
        }
        var seconds = 0.0
        for token in tokenize(text) {
            switch token.unit {
            case "min", "mins", "minute", "minutes", "minut", "minuta", "m", "'":
                seconds += token.value * 60
            case "h", "hr":
                seconds += token.value * 3600
            default:
                seconds += token.value
            }
        }
        return clamp(seconds)
    }

    private static func clamp(_ seconds: Double) -> Int {
        guard seconds.isFinite else { return 0 }
        return Int(min(max(seconds, 0), 36_000).rounded())
    }
}
