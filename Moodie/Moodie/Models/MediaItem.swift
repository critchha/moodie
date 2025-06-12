import Foundation

struct MediaItem: Identifiable, Codable, Hashable {
    let id: String // Use Plex ratingKey or a unique identifier
    let title: String
    let year: Int?
    let type: String // "movie" or "show"
    let genres: [String]
    let directors: [String]
    let cast: [String]
    let duration: Int // in minutes
    let viewCount: Int
    let summary: String
    let posterURL: String?
    let seriesTitle: String? // The show/series name for episodes (optional)
    var lastRecommended: Date? // The last time this item was recommended (optional)
} 