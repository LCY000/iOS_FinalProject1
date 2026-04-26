import SwiftUI

enum HapticEvent: Equatable {
    case selection
    case confirm
    case opponentMove
    case win
    case warn
    case connect
    case disconnect
}

extension View {
    @ViewBuilder
    func hapticFeedback(_ event: HapticEvent, trigger: some Equatable) -> some View {
        switch event {
        case .selection:
            self.sensoryFeedback(.selection, trigger: trigger)
        case .confirm:
            self.sensoryFeedback(.impact(weight: .medium), trigger: trigger)
        case .opponentMove:
            self.sensoryFeedback(.impact(weight: .light), trigger: trigger)
        case .win:
            self.sensoryFeedback(.success, trigger: trigger)
        case .warn:
            self.sensoryFeedback(.warning, trigger: trigger)
        case .connect:
            self.sensoryFeedback(.success, trigger: trigger)
        case .disconnect:
            self.sensoryFeedback(.error, trigger: trigger)
        }
    }
}
