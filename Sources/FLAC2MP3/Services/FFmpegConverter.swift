import Foundation
import AppKit

final class SafeDataBuffer: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    var value: Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

public final class FFmpegConverter: @unchecked Sendable {
    public static let shared = FFmpegConverter()

    private let processLock = NSLock()
    private var activeProcesses: Set<Process> = []
    private var isCancelledFlag = false

    private var isCancelled: Bool {
        processLock.lock()
        defer { processLock.unlock() }
        return isCancelledFlag
    }

    public func cancel() {
        processLock.lock()
        isCancelledFlag = true
        let procs = activeProcesses
        activeProcesses.removeAll()
        processLock.unlock()

        for proc in procs {
            if proc.isRunning {
                proc.terminate()
            }
        }
    }

    public func reset() {
        processLock.lock()
        isCancelledFlag = false
        activeProcesses.removeAll()
        processLock.unlock()
    }

    public static var isFFmpegAvailable: Bool {
        findExecutable("ffmpeg") != nil
    }

    public static var isFFprobeAvailable: Bool {
        findExecutable("ffprobe") != nil
    }

    public static var isFpcalcAvailable: Bool {
        findExecutable("fpcalc") != nil
    }

    // MARK: - Native Metadata Extraction via FFprobe
    public func readMetadata(from sourceURL: URL) async -> AudioMetadata? {
        guard let ffprobeURL = Self.findExecutable("ffprobe") else {
            return nil
        }

        let process = Process()
        process.executableURL = ffprobeURL
        process.arguments = [
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            sourceURL.path
        ]

        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()

        let buffer = SafeDataBuffer()

        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                outPipe.fileHandleForReading.readabilityHandler = nil
            } else {
                buffer.append(chunk)
            }
        }

        do {
            try process.run()
            process.waitUntilExit()
            outPipe.fileHandleForReading.readabilityHandler = nil
        } catch {
            return nil
        }

        let outputData = buffer.value
        guard process.terminationStatus == 0, !outputData.isEmpty else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: outputData) as? [String: Any],
              let format = json["format"] as? [String: Any],
              let tags = (format["tags"] as? [String: Any])?.reduce(into: [String: String](), { acc, pair in
                  acc[pair.key.uppercased()] = "\(pair.value)"
              }) else {
            return nil
        }

        var meta = AudioMetadata()
        meta.title = tags["TITLE"] ?? tags["TIT2"] ?? ""
        meta.artist = tags["ARTIST"] ?? tags["TPE1"] ?? tags["PERFORMER"] ?? ""
        meta.album = tags["ALBUM"] ?? tags["TALB"] ?? ""
        meta.albumArtist = tags["ALBUMARTIST"] ?? tags["ALBUM_ARTIST"] ?? tags["TPE2"] ?? meta.artist
        meta.genre = tags["GENRE"] ?? tags["TCON"] ?? ""
        meta.comment = tags["COMMENT"] ?? tags["DESCRIPTION"] ?? ""

        if let trackStr = tags["TRACK"] ?? tags["TRACKNUMBER"] ?? tags["TRCK"] {
            let parts = trackStr.components(separatedBy: "/")
            meta.trackNumber = Int(parts.first?.trimmingCharacters(in: .whitespaces) ?? "") ?? 0
            if parts.count > 1 {
                meta.trackTotal = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }

        if let discStr = tags["DISC"] ?? tags["DISCNUMBER"] ?? tags["TPOS"] {
            let parts = discStr.components(separatedBy: "/")
            meta.discNumber = Int(parts.first?.trimmingCharacters(in: .whitespaces) ?? "") ?? 1
            if parts.count > 1 {
                meta.discTotal = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 1
            }
        }

        if let dateStr = tags["DATE"] ?? tags["YEAR"] ?? tags["ORIGINALDATE"] ?? tags["TDRC"] {
            let digits = dateStr.prefix(4)
            meta.year = Int(digits) ?? 0
        }

        return meta
    }

    // MARK: - Conversion
    public func convert(
        sourceURL: URL,
        outputURL: URL,
        format: OutputFormat,
        bitrate: Bitrate,
        metadata: AudioMetadata?
    ) async throws {
        guard !isCancelled else { throw ConversionError.cancelled }

        guard let ffmpegURL = Self.findExecutable("ffmpeg") else {
            throw ConversionError.ffmpegNotFound
        }

        let outputDir = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        var tempCoverURL: URL?
        defer {
            if let temp = tempCoverURL {
                try? FileManager.default.removeItem(at: temp)
            }
        }

        var args: [String] = ["-y", "-i", sourceURL.path]

        // Handle cover art
        var hasCustomCover = false
        if let customCoverData = metadata?.coverImageData, !customCoverData.isEmpty {
            let tempCover = FileManager.default.temporaryDirectory
                .appendingPathComponent("flac2mp3_cover_\(UUID().uuidString).jpg")
            if (try? customCoverData.write(to: tempCover)) != nil {
                tempCoverURL = tempCover
                args += ["-i", tempCover.path]
                hasCustomCover = true
            }
        }

        // Map audio
        args += ["-map", "0:a:0"]

        // Format specific encoding & tag preservation
        switch format {
        case .mp3:
            if bitrate.isVBR {
                args += ["-codec:a", "libmp3lame", "-q:a", bitrate.ffmpegValue]
            } else {
                args += ["-codec:a", "libmp3lame", "-b:a", bitrate.ffmpegValue]
            }

            if hasCustomCover {
                args += ["-map", "1:v", "-c:v", "mjpeg", "-id3v2_version", "3",
                         "-metadata:s:v", "title=Album cover", "-metadata:s:v", "comment=Cover (front)"]
            } else {
                args += ["-map", "0:v?", "-c:v", "copy", "-id3v2_version", "3"]
            }
        }


        // Apply metadata tags
        if let metadata = metadata {
            if !metadata.title.isEmpty { args += ["-metadata", "title=\(metadata.title)"] }
            if !metadata.artist.isEmpty { args += ["-metadata", "artist=\(metadata.artist)"] }
            if !metadata.album.isEmpty { args += ["-metadata", "album=\(metadata.album)"] }
            if !metadata.albumArtist.isEmpty { args += ["-metadata", "album_artist=\(metadata.albumArtist)"] }
            if metadata.trackNumber > 0 {
                let trackStr = metadata.trackTotal > 0
                    ? "\(metadata.trackNumber)/\(metadata.trackTotal)"
                    : "\(metadata.trackNumber)"
                args += ["-metadata", "track=\(trackStr)"]
            }
            if metadata.discNumber > 0 {
                let discStr = metadata.discTotal > 0
                    ? "\(metadata.discNumber)/\(metadata.discTotal)"
                    : "\(metadata.discNumber)"
                args += ["-metadata", "disc=\(discStr)"]
            }
            if metadata.year > 0 { args += ["-metadata", "date=\(metadata.year)"] }
            if !metadata.genre.isEmpty { args += ["-metadata", "genre=\(metadata.genre)"] }
            if !metadata.comment.isEmpty { args += ["-metadata", "comment=\(metadata.comment)"] }
        }

        args += [outputURL.path]

        try await executeProcess(executableURL: ffmpegURL, arguments: args)
    }

    private func trackProcess(_ process: Process) throws {
        processLock.lock()
        defer { processLock.unlock() }
        if isCancelledFlag {
            throw ConversionError.cancelled
        }
        activeProcesses.insert(process)
    }

    private func untrackProcess(_ process: Process) {
        processLock.lock()
        defer { processLock.unlock() }
        activeProcesses.remove(process)
    }

    private func executeProcess(executableURL: URL, arguments: [String]) async throws {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let errPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = Pipe()

        let errBuffer = SafeDataBuffer()

        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                errPipe.fileHandleForReading.readabilityHandler = nil
            } else {
                errBuffer.append(chunk)
            }
        }

        try trackProcess(process)
        defer {
            untrackProcess(process)
        }

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { [weak self] proc in
                errPipe.fileHandleForReading.readabilityHandler = nil
                let cancelled = self?.isCancelled ?? false

                if cancelled {
                    continuation.resume(throwing: ConversionError.cancelled)
                } else if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let errorData = errBuffer.value
                    let errorStr = String(data: errorData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Error desconocido"
                    let lastLines = errorStr.components(separatedBy: .newlines).suffix(5).joined(separator: "\n")
                    continuation.resume(throwing: ConversionError.ffmpegError(lastLines))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ConversionError.ffmpegNotFound)
            }
        }
    }


    public static func findExecutable(_ name: String) -> URL? {
        let standardPaths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/opt/local/bin/\(name)",
            "/usr/bin/\(name)",
            "/bin/\(name)"
        ]

        for path in standardPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                let fullPath = "\(dir)/\(name)"
                if FileManager.default.isExecutableFile(atPath: fullPath) {
                    return URL(fileURLWithPath: fullPath)
                }
            }
        }

        return nil
    }
}


public enum ConversionError: LocalizedError {
    case ffmpegNotFound
    case ffmpegError(String)
    case cancelled
    case invalidInput
    case outputExists

    public var errorDescription: String? {
        switch self {
        case .ffmpegNotFound:
            return "FFmpeg no encontrado. Instálalo con: brew install ffmpeg"
        case .ffmpegError(let msg):
            return "FFmpeg: \(msg)"
        case .cancelled:
            return "Conversión cancelada"
        case .invalidInput:
            return "Archivo de entrada inválido o inaccesible"
        case .outputExists:
            return "El archivo de salida ya existe"
        }
    }
}

