import Foundation

struct MediaItem: Identifiable, Codable, Hashable {
    let id: String // Use Plex ratingKey or a unique identifier
    let title: String
    let year: Int?
    let type: String // "movie" or "show"
    var genres: [String]
    let directors: [String]
    let cast: [String]
    let duration: Int // in minutes
    let viewCount: Int
    var summary: String
    var posterURL: String?
    let seriesTitle: String? // The show/series name for episodes (optional)
    var lastRecommended: Date? // The last time this item was recommended (optional)
    var platforms: [String] // e.g., ["Netflix", "Hulu"]
    var country: String // e.g., "us"
    var isInTheaters: Bool? // Optional, for TMDB results
} 