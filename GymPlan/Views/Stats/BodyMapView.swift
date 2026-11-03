import SwiftUI

/// Simple front / back body diagram. Trained muscles are filled with the accent color.
struct BodyMapView: View {
    let primary: Set<String>
    var secondary: Set<String> = []

    var body: some View {
        HStack(spacing: 4) {
            BodyFigure(regions: BodyRegions.front, primary: primary, secondary: secondary)
            BodyFigure(regions: BodyRegions.back, primary: primary, secondary: secondary)
        }
    }
}

struct BodyFigure: View {
    let regions: [BodyRegion]
    let primary: Set<String>
    let secondary: Set<String>

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / BodyRegions.width, size.height / BodyRegions.height)
            let dx = (size.width - BodyRegions.width * scale) / 2
            let dy = (size.height - BodyRegions.height * scale) / 2
            let transform = CGAffineTransform(translationX: dx, y: dy).scaledBy(x: scale, y: scale)
            for region in regions {
                context.fill(region.path.applying(transform), with: .color(color(for: region)))
            }
        }
        .aspectRatio(BodyRegions.width / BodyRegions.height, contentMode: .fit)
    }

    private func color(for region: BodyRegion) -> Color {
        guard let muscle = region.muscle else { return Color.secondary.opacity(0.16) }
        if primary.contains(muscle) { return Theme.accent }
        if secondary.contains(muscle) { return Theme.accent.opacity(0.45) }
        return Color.secondary.opacity(0.28)
    }
}

struct BodyRegion {
    enum Outline {
        case ellipse
        case capsule
        case rounded(CGFloat)
        case polygon([CGPoint])
    }

    /// Muscle name as used in the exercise database, or nil for neutral body parts.
    let muscle: String?
    let outline: Outline
    let rect: CGRect

    init(_ muscle: String?, _ outline: Outline, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
        self.muscle = muscle
        self.outline = outline
        self.rect = CGRect(x: x, y: y, width: w, height: h)
    }

    var path: Path {
        switch outline {
        case .ellipse:
            return Path(ellipseIn: rect)
        case .capsule:
            return Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) / 2)
        case .rounded(let radius):
            return Path(roundedRect: rect, cornerRadius: radius)
        case .polygon(let points):
            var path = Path()
            path.addLines(points)
            path.closeSubpath()
            return path
        }
    }
}

enum BodyRegions {
    static let width: CGFloat = 100
    static let height: CGFloat = 190

    /// Body parts shared by both views (drawn first, in a neutral tone).
    private static let base: [BodyRegion] = [
        BodyRegion(nil, .ellipse, 41, 1, 18, 20),          // head
        BodyRegion(nil, .rounded(10), 34, 26, 32, 56),     // torso
        BodyRegion(nil, .rounded(6), 36, 76, 28, 14),      // hips
        BodyRegion(nil, .ellipse, 18, 88, 10, 11),         // left hand
        BodyRegion(nil, .ellipse, 72, 88, 10, 11),         // right hand
        BodyRegion(nil, .ellipse, 38, 127, 10, 9),         // left knee
        BodyRegion(nil, .ellipse, 52, 127, 10, 9),         // right knee
        BodyRegion(nil, .rounded(3), 37, 173, 11, 7),      // left foot
        BodyRegion(nil, .rounded(3), 52, 173, 11, 7)       // right foot
    ]

    static let front: [BodyRegion] = base + [
        BodyRegion("neck", .rounded(3), 44, 19, 12, 8),
        BodyRegion("shoulders", .ellipse, 24, 27, 15, 15),
        BodyRegion("shoulders", .ellipse, 61, 27, 15, 15),
        BodyRegion("chest", .rounded(6), 36, 29, 13.5, 15),
        BodyRegion("chest", .rounded(6), 50.5, 29, 13.5, 15),
        BodyRegion("biceps", .capsule, 23, 43, 9, 20),
        BodyRegion("biceps", .capsule, 68, 43, 9, 20),
        BodyRegion("forearms", .capsule, 19, 64, 9, 24),
        BodyRegion("forearms", .capsule, 72, 64, 9, 24),
        BodyRegion("abdominals", .rounded(6), 41, 46, 18, 31),
        BodyRegion("abductors", .capsule, 32.5, 82, 5.5, 20),
        BodyRegion("abductors", .capsule, 62, 82, 5.5, 20),
        BodyRegion("quadriceps", .capsule, 38, 86, 10, 40),
        BodyRegion("quadriceps", .capsule, 52, 86, 10, 40),
        BodyRegion("adductors", .capsule, 47.2, 90, 2.6, 22),
        BodyRegion("adductors", .capsule, 50.2, 90, 2.6, 22),
        BodyRegion("calves", .capsule, 38.5, 138, 9, 33),
        BodyRegion("calves", .capsule, 52.5, 138, 9, 33)
    ]

    static let back: [BodyRegion] = base + [
        BodyRegion("neck", .rounded(3), 44, 19, 12, 8),
        BodyRegion("middle back", .rounded(4), 44, 42, 12, 19),
        BodyRegion("traps", .polygon([CGPoint(x: 50, y: 21), CGPoint(x: 64, y: 30),
                                      CGPoint(x: 50, y: 47), CGPoint(x: 36, y: 30)]), 0, 0, 0, 0),
        BodyRegion("shoulders", .ellipse, 24, 27, 15, 15),
        BodyRegion("shoulders", .ellipse, 61, 27, 15, 15),
        BodyRegion("lats", .rounded(5), 35, 38, 8.5, 26),
        BodyRegion("lats", .rounded(5), 56.5, 38, 8.5, 26),
        BodyRegion("lower back", .rounded(4), 43, 63, 14, 14),
        BodyRegion("triceps", .capsule, 23, 43, 9, 20),
        BodyRegion("triceps", .capsule, 68, 43, 9, 20),
        BodyRegion("forearms", .capsule, 19, 64, 9, 24),
        BodyRegion("forearms", .capsule, 72, 64, 9, 24),
        BodyRegion("glutes", .rounded(8), 37, 78, 12.5, 18),
        BodyRegion("glutes", .rounded(8), 50.5, 78, 12.5, 18),
        BodyRegion("hamstrings", .capsule, 38, 98, 10.5, 29),
        BodyRegion("hamstrings", .capsule, 51.5, 98, 10.5, 29),
        BodyRegion("calves", .ellipse, 38, 137, 10.5, 30),
        BodyRegion("calves", .ellipse, 51.5, 137, 10.5, 30)
    ]
}
