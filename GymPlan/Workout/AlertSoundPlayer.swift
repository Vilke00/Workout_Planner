import AVFoundation
import AudioToolbox
import Foundation

/// Keeps the app alive in the background during a workout (silent audio, mixed with music)
/// and plays a beep + vibration when rest is over. Because the session uses the `.playback`
/// category it is heard over music in headphones and even with the silent switch on.
final class AlertSoundPlayer {
    static let shared = AlertSoundPlayer()

    private let engine = AVAudioEngine()
    private let keepAliveNode = AVAudioPlayerNode()
    private let beepNode = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var isConfigured = false
    private(set) var isKeepingAlive = false
    private var observers: [NSObjectProtocol] = []
    private var stopWorkItem: DispatchWorkItem?

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                            object: nil, queue: .main) { [weak self] note in
            self?.handleInterruption(note)
        })
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange,
                                            object: engine, queue: .main) { [weak self] _ in
            self?.restartIfNeeded()
        })
    }

    // MARK: Keep alive

    func startKeepAlive() {
        guard !isKeepingAlive else { return }
        isKeepingAlive = true
        activateSession()
        startEngine()
        scheduleSilence()
    }

    func stopKeepAlive() {
        isKeepingAlive = false
        stopWorkItem?.cancel()
        if isConfigured {
            keepAliveNode.stop()
            beepNode.stop()
        }
        if engine.isRunning { engine.stop() }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Rest finished

    func playRestEnd(sound: Bool, vibrate: Bool) {
        if sound {
            if !engine.isRunning {
                activateSession()
                startEngine()
            }
            // play() throws an Objective-C exception if the engine isn't running.
            if engine.isRunning, let buffer = makeBeeps() {
                beepNode.stop()
                beepNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
                beepNode.play()
            }
            if !isKeepingAlive { scheduleStop(after: 2.5) }
        }
        if vibrate {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }

    // MARK: Internals

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        engine.attach(keepAliveNode)
        engine.attach(beepNode)
        engine.connect(keepAliveNode, to: engine.mainMixerNode, format: format)
        engine.connect(beepNode, to: engine.mainMixerNode, format: format)
        isConfigured = true
    }

    private func startEngine() {
        configureIfNeeded()
        stopWorkItem?.cancel()
        guard !engine.isRunning else { return }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            print("Audio engine error: \(error)")
        }
    }

    private func scheduleSilence() {
        guard engine.isRunning, let silence = makeSilence() else { return }
        keepAliveNode.stop()
        keepAliveNode.scheduleBuffer(silence, at: nil, options: .loops, completionHandler: nil)
        keepAliveNode.play()
    }

    private func scheduleStop(after seconds: Double) {
        stopWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, !self.isKeepingAlive else { return }
            if self.isConfigured { self.beepNode.stop() }
            if self.engine.isRunning { self.engine.stop() }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        stopWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .ended { restartIfNeeded() }
    }

    private func restartIfNeeded() {
        guard isKeepingAlive else { return }
        activateSession()
        startEngine()
        scheduleSilence()
    }

    private func makeSilence() -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        for i in 0..<Int(frames) { channel[i] = 0 }
        return buffer
    }

    /// Two groups of three short beeps.
    private func makeBeeps() -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let beepLength = 0.14
        let gap = 0.08
        let groupPause = 0.35
        let frequencies: [Double] = [880, 880, 1320, 880, 880, 1320]
        var timeline: [(start: Double, freq: Double)] = []
        var t = 0.0
        for (i, f) in frequencies.enumerated() {
            timeline.append((t, f))
            t += beepLength + (i == 2 ? groupPause : gap)
        }
        let total = t + 0.1
        let frameCount = AVAudioFrameCount(total * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) { channel[i] = 0 }

        let fade = 0.006
        for beep in timeline {
            let startFrame = Int(beep.start * sampleRate)
            let length = Int(beepLength * sampleRate)
            for n in 0..<length {
                let index = startFrame + n
                guard index < Int(frameCount) else { break }
                let time = Double(n) / sampleRate
                var envelope = 1.0
                if time < fade { envelope = time / fade }
                if time > beepLength - fade { envelope = max(0, (beepLength - time) / fade) }
                let sample = sin(2 * Double.pi * beep.freq * time) * 0.75 * envelope
                channel[index] = Float(sample)
            }
        }
        return buffer
    }
}
