import Foundation
#if canImport(Darwin)
import Darwin
#endif

public class CommandServer {
    private let socketPath: String
    private var serverFd: Int32 = -1
    private var running = false

    public var onCommand: ((Command) -> StatusResponse)?

    public init(socketPath: String) {
        self.socketPath = socketPath
    }

    public func start() throws {
        serverFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFd >= 0 else { throw ServerError.socketFailed(errno) }

        unlink(socketPath)

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = Array(socketPath.utf8)
        guard pathBytes.count < MemoryLayout.size(ofValue: addr.sun_path) else {
            throw ServerError.pathTooLong
        }
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            for (i, byte) in pathBytes.enumerated() { buf[i] = byte }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(serverFd, $0, addrLen)
            }
        }
        guard bindResult == 0 else { throw ServerError.bindFailed(errno) }
        guard Darwin.listen(serverFd, 5) == 0 else { throw ServerError.listenFailed(errno) }

        running = true
        Thread.detachNewThread { self.acceptLoop() }
    }

    public func stop() {
        running = false
        Darwin.close(serverFd)
        unlink(socketPath)
    }

    // MARK: - Private

    private func acceptLoop() {
        while running {
            let clientFd = Darwin.accept(serverFd, nil, nil)
            guard clientFd >= 0 else { continue }
            Thread.detachNewThread { self.handleClient(clientFd) }
        }
    }

    private func handleClient(_ fd: Int32) {
        defer { Darwin.close(fd) }

        var buffer = [UInt8](repeating: 0, count: 256)
        let n = Darwin.read(fd, &buffer, 255)
        guard n > 0 else { return }

        let text = String(bytes: buffer[..<n], encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let reply: String
        if let command = Command.parse(text), let handler = onCommand {
            reply = handler(command).serialize() + "\n"
        } else {
            reply = "ERROR unknown command\n"
        }

        reply.withCString { ptr in _ = Darwin.write(fd, ptr, strlen(ptr)) }
    }
}

public enum ServerError: Error, LocalizedError {
    case socketFailed(Int32)
    case bindFailed(Int32)
    case listenFailed(Int32)
    case pathTooLong

    public var errorDescription: String? {
        switch self {
        case .socketFailed(let e): return "socket() failed: \(e)"
        case .bindFailed(let e):   return "bind() failed: \(e)"
        case .listenFailed(let e): return "listen() failed: \(e)"
        case .pathTooLong:         return "socket path too long"
        }
    }
}
