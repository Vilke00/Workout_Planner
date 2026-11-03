import Foundation

enum ExerciseKind: String, CaseIterable, Identifiable {
    case regular, stretch
    var id: String { rawValue }
    var title: String { self == .regular ? "Regular" : "Stretch" }
}

/// An exercise from the library (free-exercise-db) or a custom one created by import.
struct Exercise: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var primaryMuscles: [String]
    var secondaryMuscles: [String]
    var equipment: String?
    var category: String
    var level: String?
    var instructions: [String]
    /// Relative paths like "Barbell_Squat/0.jpg" (bundled as "Barbell_Squat_0.jpg").
    var images: [String]
    var isCustom: Bool
    /// Equipment shown in the filter (base equipment + equipment detected from the name).
    var equipmentTags: [String]

    init(id: String, name: String, primaryMuscles: [String] = [], secondaryMuscles: [String] = [],
         equipment: String? = nil, category: String = "strength", level: String? = nil,
         instructions: [String] = [], images: [String] = [], isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.category = category
        self.level = level
        self.instructions = instructions
        self.images = images
        self.isCustom = isCustom
        self.equipmentTags = EquipmentCatalog.tags(for: name, base: equipment)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, primaryMuscles, secondaryMuscles, equipment, category, level, instructions, images, isCustom
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, default: UUID().uuidString)
        name = c.value(.name, default: "Exercise")
        primaryMuscles = c.value(.primaryMuscles, default: [String]())
        secondaryMuscles = c.value(.secondaryMuscles, default: [String]())
        equipment = c.value(.equipment, default: String?.none)
        category = c.value(.category, default: "strength")
        level = c.value(.level, default: String?.none)
        instructions = c.value(.instructions, default: [String]())
        images = c.value(.images, default: [String]())
        isCustom = c.value(.isCustom, default: false)
        equipmentTags = EquipmentCatalog.tags(for: name, base: equipment)
    }

    static func == (lhs: Exercise, rhs: Exercise) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var kind: ExerciseKind { category.lowercased() == "stretching" ? .stretch : .regular }

    var prefersTime: Bool {
        let c = category.lowercased()
        return c == "cardio" || c == "stretching"
    }

    var muscleLine: String {
        let names = primaryMuscles.map(Fmt.title)
        return names.isEmpty ? (isCustom ? "Custom exercise" : "—") : names.joined(separator: ", ")
    }

    static func custom(name: String) -> Exercise {
        Exercise(id: "custom-" + UUID().uuidString, name: name, isCustom: true)
    }

    static func missing(id: String) -> Exercise {
        Exercise(id: id, name: "Unknown exercise", isCustom: true)
    }
}

enum EquipmentCatalog {
    static func baseName(_ raw: String?) -> String? {
        guard let raw = raw?.lowercased().trimmed, !raw.isEmpty else { return nil }
        switch raw {
        case "body only": return "Bodyweight"
        case "e-z curl bar": return "EZ Curl Bar"
        case "foam roll": return "Foam Roller"
        case "kettlebells": return "Kettlebell"
        case "bands": return "Resistance Band"
        case "dumbbell": return "Dumbbell"
        case "barbell": return "Barbell"
        case "cable": return "Cable"
        case "machine": return "Machine"
        case "medicine ball": return "Medicine Ball"
        case "exercise ball": return "Exercise Ball"
        case "other": return "Other"
        default: return raw.capitalized
        }
    }

    /// Extra equipment detected from words in the exercise name.
    private static let keywordTags: [(keys: [String], tag: String)] = [
        (["smith machine", "smith"], "Smith Machine"),
        (["trap bar", "hex bar"], "Trap Bar"),
        (["pull up", "pullup", "pullups", "pull ups", "chin up", "chinup", "chin ups", "hanging", "muscle up"], "Pull-Up Bar"),
        (["dip", "dips"], "Dip Station"),
        (["bench"], "Bench"),
        (["preacher"], "Preacher Bench"),
        (["hyperextension", "hyperextensions", "back extension", "glute ham"], "Hyperextension Bench"),
        (["landmine"], "Landmine"),
        (["sled"], "Sled"),
        (["treadmill"], "Treadmill"),
        (["bicycling stationary", "stationary bike", "recumbent bike", "spinning"], "Stationary Bike"),
        (["rowing stationary", "rowing machine", "rower"], "Rowing Machine"),
        (["elliptical"], "Elliptical"),
        (["stairmaster", "stair climber", "step mill"], "Stair Climber"),
        (["rope jumping", "jump rope", "skipping"], "Jump Rope"),
        (["box"], "Plyo Box"),
        (["ab roller", "ab wheel"], "Ab Wheel"),
        (["suspension", "trx"], "Suspension Trainer"),
        (["plate"], "Weight Plate"),
        (["tire"], "Tire"),
        (["keg"], "Keg"),
        (["atlas stone", "atlas stones"], "Atlas Stone"),
        (["yoke"], "Yoke"),
        (["log lift", "log"], "Log Bar"),
        (["chain", "chains"], "Chains"),
        (["band", "bands"], "Resistance Band"),
        (["battling ropes", "battle ropes"], "Battle Ropes"),
        (["sandbag"], "Sandbag"),
        (["kettlebell", "kettlebells"], "Kettlebell"),
        (["dumbbell", "dumbbells"], "Dumbbell"),
        (["barbell"], "Barbell"),
        (["cable"], "Cable"),
        (["leg press"], "Leg Press"),
        (["lat pulldown", "pulldown"], "Lat Pulldown"),
        (["leg extension", "leg extensions"], "Leg Extension Machine"),
        (["leg curl", "leg curls"], "Leg Curl Machine"),
        (["pec deck", "butterfly"], "Pec Deck"),
        (["hack squat"], "Hack Squat Machine"),
        (["foam"], "Foam Roller"),
        (["medicine ball"], "Medicine Ball"),
        (["swiss ball", "stability ball", "exercise ball"], "Exercise Ball"),
        (["bosu"], "BOSU Ball"),
        (["e z", "ez bar", "ez curl"], "EZ Curl Bar"),
        (["towel"], "Towel"),
        (["chair"], "Chair")
    ]

    static func normalize(_ text: String) -> String {
        let mapped = text.lowercased().map { ch -> Character in
            (ch.isLetter || ch.isNumber) ? ch : " "
        }
        return String(mapped).split(separator: " ").joined(separator: " ")
    }

    static func tags(for name: String, base: String?) -> [String] {
        var result: [String] = []
        if let b = baseName(base) { result.append(b) }
        let haystack = " " + normalize(name) + " "
        for entry in keywordTags where !result.contains(entry.tag) {
            for key in entry.keys where haystack.contains(" " + normalize(key) + " ") {
                result.append(entry.tag)
                break
            }
        }
        return result
    }
}
