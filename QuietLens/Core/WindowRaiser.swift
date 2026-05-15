import Foundation
import CoreGraphics

@_silgen_name("CGSMainConnectionID")
private func _CGSMainConnectionID() -> Int32

@_silgen_name("CGSSetWindowLevel")
private func _CGSSetWindowLevel(_ cid: Int32, _ wid: CGWindowID, _ level: Int32) -> Int32

@MainActor
final class WindowRaiser {
    static let shared = WindowRaiser()
    private let connection: Int32 = _CGSMainConnectionID()
    private var raised: Set<CGWindowID> = []
    private let normalLevel = Int32(CGWindowLevelForKey(.normalWindow))

    func setRaised(_ ids: Set<CGWindowID>, level: Int32) {
        let toDemote = raised.subtracting(ids)
        for id in toDemote {
            _ = _CGSSetWindowLevel(connection, id, normalLevel)
        }
        let toRaise = ids.subtracting(raised)
        for id in toRaise {
            _ = _CGSSetWindowLevel(connection, id, level)
        }
        raised = ids
    }

    func clearAll() {
        for id in raised {
            _ = _CGSSetWindowLevel(connection, id, normalLevel)
        }
        raised.removeAll()
    }
}
