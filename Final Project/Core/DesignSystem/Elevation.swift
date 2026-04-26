import SwiftUI

enum Elevation {
    case low
    case mid
    case high

    var radius: CGFloat {
        switch self {
        case .low:  return 4
        case .mid:  return 8
        case .high: return 14
        }
    }

    var y: CGFloat {
        switch self {
        case .low:  return 2
        case .mid:  return 4
        case .high: return 8
        }
    }

    var opacity: Double {
        switch self {
        case .low:  return 0.10
        case .mid:  return 0.15
        case .high: return 0.20
        }
    }
}

extension View {
    func elevation(_ level: Elevation) -> some View {
        shadow(color: .black.opacity(level.opacity), radius: level.radius, x: 0, y: level.y)
    }
}
