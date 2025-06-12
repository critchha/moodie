import Foundation

func getSuggestions(
    media: [MediaItem],
    user: UserPreferences,
    feedbackMap: [String: String]? = nil,
    liked: [String: Set<String>]? = nil,
    disliked: [String: Set<String>]? = nil,
    surprise: Bool = false
) -> [MediaItem] {
    // Pre-filter by time and format
    let filtered: [MediaItem] = media.filter { item in
        // Time filter
        let isShortEnough: Bool = {
            if user.time == "under_1h" {
                return item.duration <= 65 // allow a small buffer for short films
            }
            // Add more time filters if needed
            return true
        }()
        // Format filter
        let isCorrectFormat: Bool = {
            if user.format == "any" { return true }
            if user.format == "movie" { return item.type == "movie" }
            if user.format == "show" { return item.type == "show" }
            return true
        }()
        return isShortEnough && isCorrectFormat
    }
    var scored: [(item: MediaItem, score: Int)] = filtered.map {
        ($0, scoreItem($0, user: user, feedbackMap: feedbackMap, liked: liked, disliked: disliked, surprise: surprise))
    }
    scored = scored.filter { $0.score > 0 }
    scored.sort { $0.score > $1.score }
    
    // Comfort Mode: prepend top comfort items
    var recommendations: [MediaItem]
    if user.comfortMode {
        let comfortItems = filtered.filter { $0.viewCount >= 3 }
            .sorted { $0.viewCount > $1.viewCount }
            .prefix(3)
        let comfortIds = Set(comfortItems.map { $0.id })
        recommendations = Array(comfortItems) + scored.map { $0.item }.filter { !comfortIds.contains($0.id) }
    } else {
        recommendations = scored.map { $0.item }
    }
    
    // Fallback: if no recommendations, use most-watched
    if recommendations.isEmpty {
        recommendations = filtered.sorted { $0.viewCount > $1.viewCount }.prefix(3).map { $0 }
    }
    
    return recommendations
} 