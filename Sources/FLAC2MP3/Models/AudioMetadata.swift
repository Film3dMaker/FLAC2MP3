import Foundation

public struct AudioMetadata: Codable, Identifiable, Equatable {
    public var id: String = UUID().uuidString
    public var title: String = ""
    public var artist: String = ""
    public var album: String = ""
    public var albumArtist: String = ""
    public var trackNumber: Int = 0
    public var trackTotal: Int = 0
    public var discNumber: Int = 1
    public var discTotal: Int = 1
    public var year: Int = 0
    public var genre: String = ""
    public var comment: String = ""
    public var coverImageData: Data?
    public var coverImageURL: URL?
    public var musicBrainzID: String?
    public var acoustID: String?

    public init(
        id: String = UUID().uuidString,
        title: String = "",
        artist: String = "",
        album: String = "",
        albumArtist: String = "",
        trackNumber: Int = 0,
        trackTotal: Int = 0,
        discNumber: Int = 1,
        discTotal: Int = 1,
        year: Int = 0,
        genre: String = "",
        comment: String = "",
        coverImageData: Data? = nil,
        coverImageURL: URL? = nil,
        musicBrainzID: String? = nil,
        acoustID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.trackNumber = trackNumber
        self.trackTotal = trackTotal
        self.discNumber = discNumber
        self.discTotal = discTotal
        self.year = year
        self.genre = genre
        self.comment = comment
        self.coverImageData = coverImageData
        self.coverImageURL = coverImageURL
        self.musicBrainzID = musicBrainzID
        self.acoustID = acoustID
    }

    public var isComplete: Bool {
        !title.isEmpty && !artist.isEmpty
    }

    public var displayTitle: String {
        if !artist.isEmpty && !title.isEmpty {
            return "\(artist) - \(title)"
        } else if !title.isEmpty {
            return title
        }
        return ""
    }

    public static func == (lhs: AudioMetadata, rhs: AudioMetadata) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.artist == rhs.artist &&
        lhs.album == rhs.album &&
        lhs.trackNumber == rhs.trackNumber &&
        lhs.year == rhs.year &&
        lhs.genre == rhs.genre
    }
}

