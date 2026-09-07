import Foundation

public struct FileParser {
    public static let extraFileExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp",
        "txt", "m3u", "m3u8", "cue", "pdf", "log", "nfo", "sfv", "md5", "sha1", "sha256"
    ]

    public static func isFLAC(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "flac" || ext == "fla"
    }

    public static func isExtraFile(_ url: URL) -> Bool {
        extraFileExtensions.contains(url.pathExtension.lowercased())
    }

    public static func parseFilename(_ url: URL) -> AudioMetadata {
        let rawName = url.deletingPathExtension().lastPathComponent
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        var metadata = AudioMetadata()

        // 1. "01 - Artist - Title" or "01. Artist - Title" or "01 Artist - Title"
        if let match = matchRegex(pattern: #"^(\d{1,3})\s*[-._\s]+\s*(.+?)\s*[-–—]\s*(.+)$"#, in: name) {
            metadata.trackNumber = Int(match[0]) ?? 0
            metadata.artist = clean(match[1])
            metadata.title = clean(match[2])
            return metadata
        }

        // 2. "Artist - Album - 01 - Title" or "Artist - Album - 01. Title"
        if let match = matchRegex(pattern: #"^(.+?)\s*[-–—]\s*(.+?)\s*[-–—]\s*(\d{1,3})\s*[-._\s]+\s*(.+)$"#, in: name) {
            metadata.artist = clean(match[0])
            metadata.album = clean(match[1])
            metadata.trackNumber = Int(match[2]) ?? 0
            metadata.title = clean(match[3])
            return metadata
        }

        // 3. "Artist - Album - Title"
        if let match = matchRegex(pattern: #"^(.+?)\s*[-–—]\s*(.+?)\s*[-–—]\s*(.+)$"#, in: name) {
            metadata.artist = clean(match[0])
            metadata.album = clean(match[1])
            metadata.title = clean(match[2])
            return metadata
        }

        // 4. "Artist - Title"
        if let match = matchRegex(pattern: #"^(.+?)\s*[-–—]\s*(.+)$"#, in: name) {
            metadata.artist = clean(match[0])
            metadata.title = clean(match[1])
            return metadata
        }

        // 5. "01. Title" or "01 - Title" or "01 Title"
        if let match = matchRegex(pattern: #"^(\d{1,3})\s*[-._\s]+\s*(.+)$"#, in: name) {
            metadata.trackNumber = Int(match[0]) ?? 0
            metadata.title = clean(match[1])
            return metadata
        }

        metadata.title = name
        return metadata
    }

    private static func matchRegex(pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let nsString = text as NSString
        let range = NSRange(location: 0, length: nsString.length)

        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return nil
        }

        var results: [String] = []
        for i in 1..<match.numberOfRanges {
            let r = match.range(at: i)
            if r.location != NSNotFound {
                results.append(nsString.substring(with: r))
            } else {
                results.append("")
            }
        }
        return results
    }

    private static func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'_[]()"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

