import Foundation

struct UserPreferences: Codable {
    var time: String // "under_1h", "1_2h", "2plus", "any"
    var moods: [String] // e.g., ["light_funny", "intense"]
    var genres: [String] // optional, for extra filtering
    var format: String // "movie", "show", "any"
    var comfortMode: Bool
    var surprise: Bool
} 