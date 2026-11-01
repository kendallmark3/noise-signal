import SwiftUI
import UIKit

/// Concise permission or error messaging. Offers Settings only for denied permission.
struct PermissionMessageView: View {
    let permission: PermissionState
    let errorMessage: String?

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 12) {
            if let message {
                Text(message)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if permission == .denied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .underline()
            }
        }
        .frame(minHeight: 44)
        .animation(.default, value: message)
    }

    private var message: String? {
        switch permission {
        case .denied:
            return "Microphone access is off. Turn it on in Settings to listen."
        case .restricted:
            return "Microphone access is restricted on this device."
        case .undetermined, .granted:
            return errorMessage
        }
    }
}
