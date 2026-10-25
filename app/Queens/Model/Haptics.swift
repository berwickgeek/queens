import CoreHaptics
import UIKit

/// One haptic per user action, fired in the same frame as the visual change.
@MainActor
final class Haptics {
    static let shared = Haptics()

    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let firm = UIImpactFeedbackGenerator(style: .rigid)
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
        firm.prepare()
        notify.prepare()
    }

    func cross() { soft.impactOccurred(intensity: 0.6) }
    func queen() { firm.impactOccurred(intensity: 0.85) }
    func remove() { soft.impactOccurred(intensity: 0.35) }
    func clash() { notify.notificationOccurred(.error) }
    func undo() { select.selectionChanged() }

    /// Four rising taps and a soft swell.
    func solved() {
        guard let engine else { notify.notificationOccurred(.success); return }
        let steps: [(time: Double, intensity: Float, sharpness: Float)] = [
            (0.00, 0.35, 0.30), (0.10, 0.50, 0.40), (0.20, 0.70, 0.55), (0.32, 1.00, 0.75),
        ]
        var events = steps.map {
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: $0.intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: $0.sharpness),
            ], relativeTime: $0.time)
        }
        events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15),
        ], relativeTime: 0.42, duration: 0.3))
        do {
            try engine.start()
            try engine.makePlayer(with: CHHapticPattern(events: events, parameters: [])).start(atTime: 0)
        } catch {
            notify.notificationOccurred(.success)
        }
    }
}
