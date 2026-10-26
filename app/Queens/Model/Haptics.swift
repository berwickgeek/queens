import CoreHaptics
import UIKit

/// One haptic per user action, fired in the same frame as the visual change.
@MainActor
final class Haptics {
    static let shared = Haptics()

    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notify = UINotificationFeedbackGenerator()
    private let select = UISelectionFeedbackGenerator()
    private var engine: CHHapticEngine?

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        engine?.resetHandler = { [weak self] in
            Task { @MainActor in try? self?.engine?.start() }
        }
    }

    func prepare() {
        soft.prepare()
        heavy.prepare()
        try? engine?.start()
        notify.prepare()
    }

    func cross() { soft.impactOccurred(intensity: 0.6) }
    func remove() { soft.impactOccurred(intensity: 0.35) }
    func undo() { select.selectionChanged() }

    /// A heavy thud with a short low tail, so a crown lands with weight.
    func queen() {
        play([
            transient(at: 0, intensity: 1.0, sharpness: 0.5),
            continuous(at: 0.01, duration: 0.07, intensity: 0.55, sharpness: 0.2),
        ]) { heavy.impactOccurred(intensity: 1.0) }
    }

    /// Two hard knocks and a buzz: unmistakably wrong.
    func clash() {
        play([
            transient(at: 0, intensity: 1.0, sharpness: 0.9),
            transient(at: 0.1, intensity: 1.0, sharpness: 0.9),
            continuous(at: 0.17, duration: 0.14, intensity: 0.7, sharpness: 0.65),
        ]) { notify.notificationOccurred(.error) }
    }

    /// Follows the board: one rising tap per row as its crown bounces, a big thump and rumble when
    /// the board pulses, a sparkle tail under the sheen, footsteps along the royal road, a shimmer
    /// as the lanterns rise, then a press as the wax seal stamps the ribbon.
    func solved(rows n: Int) {
        var events: [CHHapticEvent] = []
        for r in 0..<n {
            let k = Float(r) / Float(max(n - 1, 1))
            events.append(transient(at: SolveTiming.rowPeak(r), intensity: 0.45 + 0.45 * k, sharpness: 0.4 + 0.4 * k))
        }
        let f = SolveTiming.finale(rows: n)
        events.append(transient(at: f, intensity: 1.0, sharpness: 0.3))
        events.append(continuous(at: f, duration: 0.6, intensity: 1.0, sharpness: 0.12))
        for k in 0..<7 {
            events.append(transient(at: f + 0.2 + Double(k) * 0.065, intensity: 0.6 - Float(k) * 0.06, sharpness: 1.0))
        }
        // A light footstep each time the royal road reaches a crown.
        for r in 0..<n {
            events.append(transient(at: SolveTiming.roadReach(r, rows: n), intensity: 0.32, sharpness: 0.85))
        }
        events.append(continuous(at: SolveTiming.lanterns(rows: n), duration: 0.5, intensity: 0.25, sharpness: 0.9))
        // The seal presses down, then settles.
        let stamp = SolveTiming.stamp(rows: n)
        events.append(transient(at: stamp, intensity: 1.0, sharpness: 0.45))
        events.append(continuous(at: stamp + 0.01, duration: 0.09, intensity: 0.6, sharpness: 0.15))
        // Let the rumble swell in and die away rather than switch off.
        let fade = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: f, value: 1.0),
            .init(relativeTime: f + 0.15, value: 0.8),
            .init(relativeTime: f + 0.6, value: 0.0),
        ], relativeTime: 0)
        play(events, curves: [fade]) { notify.notificationOccurred(.success) }
    }

    // MARK: Core Haptics

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

    private func play(_ events: [CHHapticEvent], curves: [CHHapticParameterCurve] = [], fallback: () -> Void) {
        guard let engine else { fallback(); return }
        do {
            try engine.start()
            try engine.makePlayer(with: CHHapticPattern(events: events, parameterCurves: curves)).start(atTime: CHHapticTimeImmediate)
        } catch {
            fallback()
        }
    }
}
