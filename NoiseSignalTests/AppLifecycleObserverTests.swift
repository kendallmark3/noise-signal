import AVFAudio
import UIKit
import XCTest
@testable import NoiseSignal

@MainActor
final class AppLifecycleObserverTests: XCTestCase {
    private func note(_ name: Notification.Name, _ userInfo: [AnyHashable: Any]? = nil) -> Notification {
        Notification(name: name, object: nil, userInfo: userInfo)
    }

    func testAppStateMapping() {
        XCTAssertEqual(AppLifecycleObserver.event(for: note(UIApplication.didBecomeActiveNotification), inputAvailable: true), .didBecomeActive)
        XCTAssertEqual(AppLifecycleObserver.event(for: note(UIApplication.didEnterBackgroundNotification), inputAvailable: true), .didEnterBackground)
    }

    func testInterruptionMapping() {
        let began = note(AVAudioSession.interruptionNotification, [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        let ended = note(AVAudioSession.interruptionNotification, [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue])
        XCTAssertEqual(AppLifecycleObserver.event(for: began, inputAvailable: true), .interruptionBegan)
        XCTAssertEqual(AppLifecycleObserver.event(for: ended, inputAvailable: true), .interruptionEnded)
        XCTAssertNil(AppLifecycleObserver.event(for: note(AVAudioSession.interruptionNotification), inputAvailable: true))
    }

    func testRouteChangeMapping() {
        let change = note(AVAudioSession.routeChangeNotification, [
            AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
        ])
        XCTAssertEqual(AppLifecycleObserver.event(for: change, inputAvailable: false), .inputUnavailable)
        XCTAssertEqual(AppLifecycleObserver.event(for: change, inputAvailable: true), .routeChanged)
    }

    func testUnrelatedNotificationIsIgnored() {
        XCTAssertNil(AppLifecycleObserver.event(for: note(Notification.Name("other")), inputAvailable: true))
    }
}
