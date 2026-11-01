import AVFAudio
import UIKit

/// System events the view model reacts to. None of them ever restarts monitoring.
enum LifecycleEvent: Equatable, Sendable {
    case didBecomeActive
    case didEnterBackground
    case interruptionBegan
    case interruptionEnded
    /// A route change left no usable input.
    case inputUnavailable
    /// A route change that still has an input (refresh state only).
    case routeChanged
    case mediaServicesReset
}

/// Bridges NotificationCenter into main-actor callbacks. Observers are delivered on the main
/// queue and mapped to `LifecycleEvent` before reaching the view model.
@MainActor
final class AppLifecycleObserver {
    private let center: NotificationCenter
    /// Written only during init; read in deinit.
    nonisolated(unsafe) private var tokens: [NSObjectProtocol] = []

    init(
        center: NotificationCenter = .default,
        inputAvailable: @escaping @Sendable () -> Bool = { AVAudioSession.sharedInstance().isInputAvailable },
        handler: @escaping @MainActor @Sendable (LifecycleEvent) -> Void
    ) {
        self.center = center
        let names: [Notification.Name] = [
            UIApplication.didBecomeActiveNotification,
            UIApplication.didEnterBackgroundNotification,
            AVAudioSession.interruptionNotification,
            AVAudioSession.routeChangeNotification,
            AVAudioSession.mediaServicesWereResetNotification
        ]
        for name in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { notification in
                // Map to a Sendable event first so the non-Sendable Notification never crosses isolation.
                guard let event = AppLifecycleObserver.event(for: notification, inputAvailable: inputAvailable()) else { return }
                MainActor.assumeIsolated {
                    handler(event)
                }
            }
            tokens.append(token)
        }
    }

    deinit {
        for token in tokens {
            center.removeObserver(token)
        }
    }

    /// Pure mapping from a notification to an event. Unit-testable.
    nonisolated static func event(for notification: Notification, inputAvailable: Bool) -> LifecycleEvent? {
        switch notification.name {
        case UIApplication.didBecomeActiveNotification:
            return .didBecomeActive

        case UIApplication.didEnterBackgroundNotification:
            return .didEnterBackground

        case AVAudioSession.interruptionNotification:
            guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return nil }
            switch type {
            case .began:
                return .interruptionBegan
            case .ended:
                return .interruptionEnded
            @unknown default:
                return nil
            }

        case AVAudioSession.routeChangeNotification:
            return inputAvailable ? .routeChanged : .inputUnavailable

        case AVAudioSession.mediaServicesWereResetNotification:
            return .mediaServicesReset

        default:
            return nil
        }
    }
}
