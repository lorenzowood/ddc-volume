import Foundation

public enum Command {
    case up(Int)
    case down(Int)
    case set(Int)
    case mute
    case unmute
    case toggleMute
    case get

    public static func parse(_ text: String) -> Command? {
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }
        guard let verb = parts.first?.uppercased() else { return nil }

        switch verb {
        case "UP":
            guard let n = parts.dropFirst().first.flatMap(Int.init), n > 0 else { return nil }
            return .up(n)
        case "DOWN":
            guard let n = parts.dropFirst().first.flatMap(Int.init), n > 0 else { return nil }
            return .down(n)
        case "SET":
            guard let n = parts.dropFirst().first.flatMap(Int.init) else { return nil }
            return .set(n)
        case "MUTE":       return .mute
        case "UNMUTE":     return .unmute
        case "TOGGLEMUTE": return .toggleMute
        case "GET":        return .get
        default:           return nil
        }
    }

    public func serialize() -> String {
        switch self {
        case .up(let n):    return "UP \(n)"
        case .down(let n):  return "DOWN \(n)"
        case .set(let n):   return "SET \(n)"
        case .mute:         return "MUTE"
        case .unmute:       return "UNMUTE"
        case .toggleMute:   return "TOGGLEMUTE"
        case .get:          return "GET"
        }
    }
}

public struct StatusResponse {
    public let desiredVolume: Int
    public let lastSentVolume: Int?
    public let isMuted: Bool

    public init(desiredVolume: Int, lastSentVolume: Int?, isMuted: Bool) {
        self.desiredVolume = desiredVolume
        self.lastSentVolume = lastSentVolume
        self.isMuted = isMuted
    }

    public func serialize() -> String {
        let sent = lastSentVolume.map(String.init) ?? "-"
        return "STATUS desired=\(desiredVolume) lastSent=\(sent) muted=\(isMuted)"
    }

    public static func parse(_ text: String) -> StatusResponse? {
        guard text.hasPrefix("STATUS ") else { return nil }
        var desired: Int?
        var lastSent: Int?
        var muted: Bool?
        for part in text.dropFirst(7).components(separatedBy: " ") {
            let kv = part.components(separatedBy: "=")
            guard kv.count == 2 else { continue }
            switch kv[0] {
            case "desired":  desired  = Int(kv[1])
            case "lastSent": lastSent = kv[1] == "-" ? nil : Int(kv[1])
            case "muted":    muted    = kv[1] == "true"
            default: break
            }
        }
        guard let d = desired, let m = muted else { return nil }
        return StatusResponse(desiredVolume: d, lastSentVolume: lastSent, isMuted: m)
    }
}
