import Foundation
import SwiftData

@Model
final class AppSettings {
    var rsvpSpeed: Int
    var ttsSpeedMultiplier: Double
    var focusColor: String
    var selectedVoiceId: String?
    var appearanceMode: String

    init(
        rsvpSpeed: Int = 300,
        ttsSpeedMultiplier: Double = 1.0,
        focusColor: String = "#FF3B30",
        selectedVoiceId: String? = nil,
        appearanceMode: String = "system"
    ) {
        self.rsvpSpeed = rsvpSpeed
        self.ttsSpeedMultiplier = ttsSpeedMultiplier
        self.focusColor = focusColor
        self.selectedVoiceId = selectedVoiceId
        self.appearanceMode = appearanceMode
    }
}
