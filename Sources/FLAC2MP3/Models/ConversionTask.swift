import Foundation

public enum OutputFormat: String, CaseIterable, Codable, Identifiable {
    case mp3 = "MP3"

    public var id: String { rawValue }

    public var fileExtension: String {
        return "mp3"
    }

    public var mimeType: String {
        return "audio/mpeg"
    }
}


public enum Bitrate: String, CaseIterable, Codable, Identifiable {
    case b320 = "320 kbps (Máxima)"
    case b256 = "256 kbps (Muy alta)"
    case b192 = "192 kbps (Alta)"
    case b128 = "128 kbps (Estándar)"
    case v0 = "V0 (~245 kbps VBR)"
    case v2 = "V2 (~190 kbps VBR)"

    public var id: String { rawValue }

    public var ffmpegValue: String {
        switch self {
        case .b320: return "320k"
        case .b256: return "256k"
        case .b192: return "192k"
        case .b128: return "128k"
        case .v0: return "0"
        case .v2: return "2"
        }
    }

    public var isVBR: Bool {
        self == .v0 || self == .v2
    }
}

public enum RecognitionMode: String, CaseIterable, Codable, Identifiable {
    case keepOriginal = "Preservar tags originales de FLAC"
    case hybrid = "Híbrido (Tags originales + Enriquecer)"
    case musicbrainz = "MusicBrainz + AcoustID (Fingerprint)"
    case filename = "Por nombre de archivo"

    public var id: String { rawValue }
}

public enum OutputDestinationMode: String, CaseIterable, Codable, Identifiable {
    case subfolderMP3 = "Subcarpeta 'MP3' dentro de cada carpeta"
    case customFolder = "Ubicación personalizada (Elegir carpeta)..."
    case sameAsSource = "En la misma carpeta original (sin subcarpeta)"

    public var id: String { rawValue }
}


public enum ConversionStatus: String, Codable {
    case pending = "Pendiente"
    case readingMetadata = "Leyendo tags..."
    case recognizing = "Reconociendo..."
    case converting = "Convirtiendo..."
    case copying = "Copiando..."
    case completed = "Completado"
    case failed = "Error"
    case cancelled = "Cancelado"
}

public struct ExtraFileItem: Hashable, Identifiable {
    public var id: String { sourceURL.path }
    public let sourceURL: URL
    public let rootFolderURL: URL?
    public let rootFolderName: String?
    public let relativePath: String

    public init(
        sourceURL: URL,
        rootFolderURL: URL? = nil,
        rootFolderName: String? = nil,
        relativePath: String
    ) {
        self.sourceURL = sourceURL
        self.rootFolderURL = rootFolderURL
        self.rootFolderName = rootFolderName
        self.relativePath = relativePath
    }
}

public struct ConversionTask: Identifiable, Hashable {
    public let id: UUID
    public let sourceURL: URL
    public let rootFolderURL: URL?
    public let rootFolderName: String?
    public let relativePath: String
    public var status: ConversionStatus
    public var progress: Double
    public var outputURL: URL?
    public var errorMessage: String?
    public var metadata: AudioMetadata?
    public var fileSizeBytes: Int64?
    public var durationSeconds: Double?

    public init(
        id: UUID = UUID(),
        sourceURL: URL,
        rootFolderURL: URL? = nil,
        rootFolderName: String? = nil,
        relativePath: String,
        status: ConversionStatus = .pending,
        progress: Double = 0,
        outputURL: URL? = nil,
        errorMessage: String? = nil,
        metadata: AudioMetadata? = nil,
        fileSizeBytes: Int64? = nil,
        durationSeconds: Double? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.rootFolderURL = rootFolderURL
        self.rootFolderName = rootFolderName
        self.relativePath = relativePath
        self.status = status
        self.progress = progress
        self.outputURL = outputURL
        self.errorMessage = errorMessage
        self.metadata = metadata
        self.fileSizeBytes = fileSizeBytes
        self.durationSeconds = durationSeconds
    }

    public var sourceFileName: String {
        sourceURL.lastPathComponent
    }

    public var formattedFileSize: String {
        let bytes: Int64
        if let size = fileSizeBytes {
            bytes = size
        } else if let resourceValues = try? sourceURL.resourceValues(forKeys: [.fileSizeKey]), let size = resourceValues.fileSize {
            bytes = Int64(size)
        } else {
            return ""
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: ConversionTask, rhs: ConversionTask) -> Bool {
        lhs.id == rhs.id &&
        lhs.status == rhs.status &&
        lhs.progress == rhs.progress &&
        lhs.errorMessage == rhs.errorMessage
    }
}


