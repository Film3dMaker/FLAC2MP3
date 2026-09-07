import Foundation

public class AudioRecognizer {
    private let session: URLSession
    private let musicBrainzURL = "https://musicbrainz.org/ws/2"
    private let acoustIDURL = "https://api.acoustid.org/v2/lookup"
    private let acoustIDKey = "8XGk9l22"
    private var isCancelled = false

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }

    public func cancel() {
        isCancelled = true
    }

    public func reset() {
        isCancelled = false
    }

    public func recognize(url: URL, mode: RecognitionMode) async -> AudioMetadata {
        guard !isCancelled else { return AudioMetadata() }

        switch mode {
        case .keepOriginal:
            if let native = await FFmpegConverter.shared.readMetadata(from: url), !native.title.isEmpty {
                return native
            }
            return FileParser.parseFilename(url)

        case .filename:
            return await recognizeByFilename(url)

        case .musicbrainz:
            return await recognizeByAcoustID(url)

        case .hybrid:
            var metadata = await FFmpegConverter.shared.readMetadata(from: url) ?? AudioMetadata()
            if metadata.title.isEmpty || metadata.artist.isEmpty {
                let parsed = FileParser.parseFilename(url)
                if metadata.title.isEmpty { metadata.title = parsed.title }
                if metadata.artist.isEmpty { metadata.artist = parsed.artist }
                if metadata.album.isEmpty { metadata.album = parsed.album }
                if metadata.trackNumber == 0 { metadata.trackNumber = parsed.trackNumber }
            }

            if !metadata.isComplete {
                let acoustMetadata = await recognizeByAcoustID(url)
                if acoustMetadata.isComplete {
                    return acoustMetadata
                }
            }
            return metadata
        }
    }

    private func recognizeByFilename(_ url: URL) async -> AudioMetadata {
        let metadata = FileParser.parseFilename(url)
        if metadata.isComplete {
            let enriched = await searchMusicBrainz(artist: metadata.artist, album: metadata.album, title: metadata.title)
            if enriched.isComplete {
                return enriched
            }
            return metadata
        }
        return metadata
    }

    private func recognizeByAcoustID(_ url: URL) async -> AudioMetadata {
        guard !isCancelled else { return AudioMetadata() }

        guard let (fingerprint, duration) = await generateFingerprint(url) else {
            return AudioMetadata()
        }

        guard !isCancelled else { return AudioMetadata() }
        guard let recordingID = await lookupAcoustID(fingerprint: fingerprint, duration: duration) else {
            return AudioMetadata()
        }

        guard !isCancelled else { return AudioMetadata() }
        return await lookupMusicBrainz(recordingID)
    }

    private func searchMusicBrainz(artist: String, album: String, title: String) async -> AudioMetadata {
        var queryParts: [String] = []
        if !artist.isEmpty { queryParts.append("artist:\"\(artist)\"") }
        if !album.isEmpty { queryParts.append("release:\"\(album)\"") }
        if !title.isEmpty { queryParts.append("recording:\"\(title)\"") }

        let query = queryParts.joined(separator: " AND ")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlStr = "\(musicBrainzURL)/recording/?query=\(encoded)&fmt=json&limit=1"
        guard let url = URL(string: urlStr) else { return AudioMetadata() }

        var request = URLRequest(url: url)
        request.setValue("FLAC2MP3/1.0.0 (https://github.com/nexoshape/FLAC2MP3)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await session.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let recordings = json?["recordings"] as? [[String: Any]], let first = recordings.first {
                return await parseMusicBrainzRecording(first)
            }
        } catch {}
        return AudioMetadata()
    }

    private func generateFingerprint(_ url: URL) async -> (fingerprint: String, duration: Int)? {
        guard let fpcalcURL = FFmpegConverter.findExecutable("fpcalc") else {
            return nil
        }

        let process = Process()
        process.executableURL = fpcalcURL
        process.arguments = ["-raw", "-length", "120", url.path]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let outBuffer = SafeDataBuffer()
        let errBuffer = SafeDataBuffer()

        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                outPipe.fileHandleForReading.readabilityHandler = nil
            } else {
                outBuffer.append(chunk)
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                errPipe.fileHandleForReading.readabilityHandler = nil
            } else {
                errBuffer.append(chunk)
            }
        }

        do {
            try process.run()
            process.waitUntilExit()
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }

        let output = String(data: outBuffer.value, encoding: .utf8) ?? ""
        let errorOutput = String(data: errBuffer.value, encoding: .utf8) ?? ""

        var fingerprint: String?
        var duration: Int = 30

        for line in (output + "\n" + errorOutput).components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("FINGERPRINT=") {
                fingerprint = String(trimmed.dropFirst("FINGERPRINT=".count))
            }
            if trimmed.hasPrefix("DURATION=") {
                let durStr = String(trimmed.dropFirst("DURATION=".count))
                duration = Int(Float(durStr) ?? 30)
            }
        }

        guard let fp = fingerprint, !fp.isEmpty else { return nil }
        return (fp, max(1, duration))
    }


    private func lookupAcoustID(fingerprint: String, duration: Int) async -> String? {
        guard !isCancelled else { return nil }

        guard var components = URLComponents(string: acoustIDURL) else { return nil }
        components.queryItems = [
            URLQueryItem(name: "client", value: acoustIDKey),
            URLQueryItem(name: "fingerprint", value: fingerprint),
            URLQueryItem(name: "duration", value: String(duration)),
            URLQueryItem(name: "meta", value: "recordings")
        ]

        guard let url = components.url else { return nil }

        do {
            let (data, _) = try await session.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            if let results = json?["results"] as? [[String: Any]] {
                for result in results {
                    if let recordings = result["recordings"] as? [[String: Any]] {
                        for recording in recordings {
                            if let id = recording["id"] as? String {
                                return id
                            }
                        }
                    }
                }
            }
        } catch {}
        return nil
    }

    private func lookupMusicBrainz(_ recordingID: String) async -> AudioMetadata {
        guard !isCancelled else { return AudioMetadata() }

        let urlStr = "\(musicBrainzURL)/recording/\(recordingID)?fmt=json&inc=artists+releases+artist-credits+tags"
        guard let url = URL(string: urlStr) else { return AudioMetadata() }

        var request = URLRequest(url: url)
        request.setValue("FLAC2MP3/1.0.0 (https://github.com/nexoshape/FLAC2MP3)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await session.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return await parseMusicBrainzRecording(json)
        } catch {
            return AudioMetadata()
        }
    }

    private func parseMusicBrainzRecording(_ json: [String: Any]?) async -> AudioMetadata {
        var metadata = AudioMetadata()

        guard let json = json else { return metadata }

        if let title = json["title"] as? String {
            metadata.title = title
        }
        if let id = json["id"] as? String {
            metadata.musicBrainzID = id
        }

        if let artistCredit = json["artist-credit"] as? [[String: Any]] {
            let names = artistCredit.compactMap { $0["name"] as? String }
            metadata.artist = names.joined(separator: ", ")
            metadata.albumArtist = metadata.artist
        }

        if let releases = json["releases"] as? [[String: Any]], let release = releases.first {
            if let title = release["title"] as? String {
                metadata.album = title
            }
            if let date = release["date"] as? String {
                metadata.year = Int(date.prefix(4)) ?? 0
            }
            if let releaseID = release["id"] as? String {
                let coverData = await downloadCoverArt(releaseID: releaseID)
                metadata.coverImageData = coverData
                if coverData != nil {
                    metadata.coverImageURL = URL(string: "https://coverartarchive.org/release/\(releaseID)/front-500")
                }
            }
            if let groupID = release["release-group"] as? [String: Any], let id = groupID["id"] as? String {
                if metadata.coverImageData == nil {
                    metadata.coverImageData = await downloadCoverArt(releaseID: id, useReleaseGroup: true)
                }
            }
        }

        if let tags = json["tags"] as? [[String: Any]], let firstTag = tags.first {
            metadata.genre = firstTag["name"] as? String ?? ""
        }

        return metadata
    }

    private func downloadCoverArt(releaseID: String, useReleaseGroup: Bool = false) async -> Data? {
        let sizes = useReleaseGroup
            ? ["", "-250", "-500"]
            : ["-500", "-250", ""]

        for size in sizes {
            let baseURL = useReleaseGroup
                ? "https://coverartarchive.org/release-group/\(releaseID)/front\(size)"
                : "https://coverartarchive.org/release/\(releaseID)/front\(size)"
            guard let url = URL(string: baseURL) else { continue }
            do {
                var request = URLRequest(url: url)
                request.setValue("FLAC2MP3/1.0.0 (https://github.com/nexoshape/FLAC2MP3)", forHTTPHeaderField: "User-Agent")
                request.timeoutInterval = 8
                let (data, response) = try await session.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200,
                   !data.isEmpty {
                    return data
                }
            } catch {}
        }
        return nil
    }
}

