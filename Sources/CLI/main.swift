import Foundation
import Common
#if canImport(Darwin)
import Darwin
#endif

let args = CommandLine.arguments.dropFirst()

guard let verb = args.first else {
    printUsage()
    exit(1)
}

let commandText: String

switch verb.lowercased() {
case "up":
    guard let n = args.dropFirst().first.flatMap(Int.init), n > 0 else { die("up requires a positive integer") }
    commandText = "UP \(n)"
case "down":
    guard let n = args.dropFirst().first.flatMap(Int.init), n > 0 else { die("down requires a positive integer") }
    commandText = "DOWN \(n)"
case "set":
    guard let n = args.dropFirst().first.flatMap(Int.init) else { die("set requires an integer") }
    commandText = "SET \(n)"
case "get":
    commandText = "GET"
case "mute":
    commandText = "MUTE"
case "unmute":
    commandText = "UNMUTE"
case "togglemute":
    commandText = "TOGGLEMUTE"
default:
    printUsage()
    exit(1)
}

guard let response = send(commandText, to: Config.socketPath) else {
    fputs("ddc-volume: daemon not running (no socket at \(Config.socketPath))\n", stderr)
    exit(1)
}

let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

if verb.lowercased() == "get" {
    if let status = StatusResponse.parse(trimmed) {
        if let sent = status.lastSentVolume, sent != status.desiredVolume {
            print("Volume: \(status.desiredVolume) (last sent: \(sent) — pending sync)")
        } else {
            print("Volume: \(status.desiredVolume)")
        }
        print("Muted:  \(status.isMuted ? "yes" : "no")")
    } else {
        print(trimmed)
    }
}
// write commands: respond silently on success

// MARK: - Helpers

func send(_ text: String, to socketPath: String) -> String? {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return nil }
    defer { Darwin.close(fd) }

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)

    let pathBytes = Array(socketPath.utf8)
    guard pathBytes.count < MemoryLayout.size(ofValue: addr.sun_path) else { return nil }
    withUnsafeMutableBytes(of: &addr.sun_path) { buf in
        for (i, byte) in pathBytes.enumerated() { buf[i] = byte }
    }

    let connected = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }
    guard connected == 0 else { return nil }

    let message = text + "\n"
    message.withCString { _ = Darwin.write(fd, $0, strlen($0)) }

    var buffer = [UInt8](repeating: 0, count: 1024)
    let n = Darwin.read(fd, &buffer, 1023)
    guard n > 0 else { return nil }
    return String(bytes: buffer[..<n], encoding: .utf8)
}

func printUsage() {
    print("""
    Usage: ddc-volume <command> [args]

    Commands:
      up <n>        Increase volume by n
      down <n>      Decrease volume by n
      set <n>       Set volume to n (0-100)
      get           Show current volume and mute state
      mute          Mute the monitor
      unmute        Unmute the monitor
      togglemute    Toggle mute state
    """)
}

func die(_ msg: String) -> Never {
    fputs("ddc-volume: \(msg)\n", stderr)
    exit(1)
}
