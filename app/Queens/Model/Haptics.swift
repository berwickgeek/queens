import AVFoundation
import CoreHaptics
import UIKit

/// One haptic per user action, fired in the same frame as the visual change. Sounds (the wood and bell
/// set from `tools/make_sounds.py`) ride in the same Core Haptics patterns, so each lands with its haptic.
@MainActor
final class Haptics {
    static let shared = Haptics()
    /// UserDefaults key for the sound switch. Sound is on until turned off.
    static let soundKey = "sound"

    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notify = UINotificationFeedbackGenerator()
    private let select = UISelectionFeedbackGenerator()
    private var engine: CHHapticEngine?
    /// iPad has no Taptic Engine but still plays the sounds through the same patterns.
    private let feels = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var sounds: [String: CHHapticAudioResourceID] = [:]

    private init() {
        // Ambient obeys the silent switch and mixes with whatever else is playing.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        let caps = CHHapticEngine.capabilitiesForHardware()
        guard caps.supportsHaptics || caps.supportsAudio else { return }
        engine = try? CHHapticEngine(audioSession: .sharedInstance())
        engine?.isAutoShutdownEnabled = true
        engine?.resetHandler = { [weak self] in
            Task { @MainActor in
                try? self?.engine?.start()
                self?.registerSounds()
            }
        }
        registerSounds()
    }

    private var soundOn: Bool { UserDefaults.standard.object(forKey: Self.soundKey) as? Bool ?? true }

    private func registerSounds() {
        sounds = [:]
        guard let engine, let urls = Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: nil) else { return }
        for url in urls {
            if let id = try? engine.registerAudioResource(url) {
                sounds[url.deletingPathExtension().lastPathComponent] = id
            }
        }
    }

    func prepare() {
        soft.prepare()
        heavy.prepare()
        try? engine?.start()
        notify.prepare()
    }

    func cross() {
        soft.impactOccurred(intensity: 0.6)
        play([sound("tick", at: 0, volume: 0.5)])
    }

    func remove() {
        soft.impactOccurred(intensity: 0.35)
        play([sound("tick", at: 0, volume: 0.3)])
    }

    func undo() { select.selectionChanged() }

    /// A thud with a short low tail. Crown `placed` of `n` lands heavier than the one before and
    /// rings one step higher up the scale, so the board sounds closer to done as it fills.
    func queen(placed: Int, of n: Int) {
        let k = Float(placed - 1) / Float(max(n - 1, 1))
        play([
            transient(at: 0, intensity: 0.75 + 0.25 * k, sharpness: 0.5 - 0.15 * k),
            continuous(at: 0.01, duration: 0.07 + 0.06 * Double(k), intensity: 0.4 + 0.35 * k, sharpness: 0.2),
            sound(note(placed - 1), at: 0, volume: 0.6 + 0.4 * k),
        ]) { heavy.impactOccurred(intensity: CGFloat(0.75 + 0.25 * k)) }
    }

    /// The last crown: the top note and its octave, then a rumble that swells through the pause
    /// before the board bounces, so the finale is felt coming.
    func lastCrown(rows n: Int) {
        let swell = SolveTiming.entrance - 0.03
        let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: 0, value: 1.0),
            .init(relativeTime: 0.09, value: 0.15),
            .init(relativeTime: swell, value: 1.0),
        ], relativeTime: 0)
        play([
            transient(at: 0, intensity: 1.0, sharpness: 0.35),
            continuous(at: 0.01, duration: 0.12, intensity: 0.75, sharpness: 0.2),
            continuous(at: 0.13, duration: swell - 0.13, intensity: 0.55, sharpness: 0.1),
            sound(note(n - 1), at: 0),
            sound(note(n + 4), at: 0.09, volume: 0.7),
        ], curves: [curve]) { heavy.impactOccurred(intensity: 1.0) }
    }

    /// A kingdom with every cell marked: two quick high chimes.
    func sealed(after delay: Double = 0) {
        play([
            transient(at: delay, intensity: 0.4, sharpness: 0.8),
            transient(at: delay + 0.08, intensity: 0.55, sharpness: 0.9),
            sound("note_07", at: delay, volume: 0.45),
            sound("note_10", at: delay + 0.08, volume: 0.5),
        ]) { select.selectionChanged() }
    }

    /// Two hard knocks and a buzz: unmistakably wrong.
    func clash() {
        play([
            transient(at: 0, intensity: 1.0, sharpness: 0.9),
            transient(at: 0.1, intensity: 1.0, sharpness: 0.9),
            continuous(at: 0.17, duration: 0.14, intensity: 0.7, sharpness: 0.65),
            sound("clash", at: 0, volume: 0.7),
        ]) { notify.notificationOccurred(.error) }
    }

    /// Follows the board: one rising tap and bar per row as its crown bounces, a big thump, rumble and
    /// bell chord when the board pulses, a sparkle tail under the sheen, footsteps along the royal road,
    /// a shimmer and random bells as the lanterns rise, then a press as the wax seal stamps the ribbon.
    /// A new best adds a run of bells after the seal; a flourish adds its own.
    func solved(rows n: Int, best: Bool, flourish: Flourish) {
        var events: [CHHapticEvent?] = []
        for r in 0..<n {
            let k = Float(r) / Float(max(n - 1, 1))
            events.append(transient(at: SolveTiming.rowPeak(r), intensity: 0.45 + 0.45 * k, sharpness: 0.4 + 0.4 * k))
            events.append(sound(note(r + 5), at: SolveTiming.rowPeak(r), volume: 0.45 + 0.35 * k))
        }
        let f = SolveTiming.finale(rows: n)
        events.append(transient(at: f, intensity: 1.0, sharpness: 0.3))
        events.append(continuous(at: f, duration: 0.6, intensity: 1.0, sharpness: 0.12))
        events.append(sound("chord", at: f))
        for k in 0..<7 {
            events.append(transient(at: f + 0.2 + Double(k) * 0.065, intensity: 0.6 - Float(k) * 0.06, sharpness: 1.0))
        }
        // A light footstep each time the royal road reaches a crown.
        for r in 0..<n {
            events.append(transient(at: SolveTiming.roadReach(r, rows: n), intensity: 0.32, sharpness: 0.85))
            events.append(sound("tick", at: SolveTiming.roadReach(r, rows: n), volume: 0.25))
        }
        let lanterns = SolveTiming.lanterns(rows: n)
        events.append(continuous(at: lanterns, duration: 0.5, intensity: 0.25, sharpness: 0.9))
        // Lantern bells at random pitches and gaps, so no two solves ring the same.
        let span = SolveTiming.lanternSpan(flourish) - 0.6
        let bells = flourish == .festival ? 14 : 6
        var t = lanterns + 0.15
        for _ in 0..<bells where t < lanterns + span {
            events.append(sound("lantern_\(Int.random(in: 0..<5))", at: t, volume: Float.random(in: 0.2...0.35)))
            t += span / Double(bells) * Double.random(in: 0.6...1.4)
        }
        if flourish == .comet {
            let c = SolveTiming.comet(rows: n)
            events.append(sound("comet", at: c, volume: 0.7))
            events.append(continuous(at: c, duration: SolveTiming.cometFlight, intensity: 0.22, sharpness: 1.0))
        }
        // The seal presses down, then settles.
        let stamp = SolveTiming.stamp(rows: n)
        events.append(transient(at: stamp, intensity: 1.0, sharpness: 0.45))
        events.append(continuous(at: stamp + 0.01, duration: 0.09, intensity: 0.6, sharpness: 0.15))
        events.append(sound("seal", at: stamp, volume: 0.8))
        if best {
            for k in 0..<5 {
                events.append(transient(at: stamp + SolveTiming.bestRun + Double(k) * 0.08, intensity: 0.35 + 0.12 * Float(k), sharpness: 0.9))
            }
            events.append(sound("best", at: stamp + SolveTiming.bestRun, volume: 0.8))
        }
        // Let the rumble swell in and die away rather than switch off.
        let fade = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: f, value: 1.0),
            .init(relativeTime: f + 0.15, value: 0.8),
            .init(relativeTime: f + 0.6, value: 0.0),
            .init(relativeTime: f + 0.61, value: 1.0),
        ], relativeTime: 0)
        play(events, curves: [fade]) { notify.notificationOccurred(.success) }
    }

    // MARK: Core Haptics

    /// The marimba bar `i` steps up the pentatonic scale from D4.
    private func note(_ i: Int) -> String { String(format: "note_%02d", min(max(i, 0), 15)) }

    private func sound(_ name: String, at time: Double, volume: Float = 1) -> CHHapticEvent? {
        guard soundOn, let id = sounds[name] else { return nil }
        return CHHapticEvent(audioResourceID: id, parameters: [
            CHHapticEventParameter(parameterID: .audioVolume, value: volume),
        ], relativeTime: time)
    }

    private func transient(at time: Double, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time)
    }

    private func continuous(at time: Double, duration: Double, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time, duration: duration)
    }

    private func play(_ events: [CHHapticEvent?], curves: [CHHapticParameterCurve] = [], fallback: () -> Void = {}) {
        var events = events.compactMap { $0 }
        var curves = curves
        if !feels {
            events = events.filter { $0.type == .audioCustom }
            curves = []
        }
        guard let engine, !events.isEmpty else { fallback(); return }
        do {
            try engine.start()
            try engine.makePlayer(with: CHHapticPattern(events: events, parameterCurves: curves)).start(atTime: CHHapticTimeImmediate)
        } catch {
            fallback()
        }
    }
}
