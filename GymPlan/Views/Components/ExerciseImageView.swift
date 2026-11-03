import SwiftUI
import UIKit

/// Shows the exercise photos. The two frames (start / end position) alternate like a GIF.
struct ExerciseImageView: View {
    let exercise: Exercise?
    var animated: Bool = true
    var fill: Bool = true

    var body: some View {
        if let exercise, !exercise.images.isEmpty {
            if animated && exercise.images.count > 1 {
                TimelineView(.periodic(from: .now, by: 0.9)) { context in
                    let frame = Int(context.date.timeIntervalSinceReferenceDate / 0.9) % 2
                    frameView(exercise, frame: frame)
                }
            } else {
                frameView(exercise, frame: 0)
            }
        } else {
            placeholder
        }
    }

    @ViewBuilder
    private func frameView(_ exercise: Exercise, frame: Int) -> some View {
        if let image = ImageCache.shared.image(for: exercise, frame: frame) {
            if fill {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Theme.card2
            Image(systemName: "dumbbell.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    func image(for exercise: Exercise, frame: Int) -> UIImage? {
        guard exercise.images.indices.contains(frame) else { return nil }
        // "Barbell_Squat/0.jpg" is bundled as "ExerciseImages/Barbell_Squat_0.jpg"
        let name = exercise.images[frame]
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ".jpg", with: "")
        let key = name as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "ExerciseImages"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
