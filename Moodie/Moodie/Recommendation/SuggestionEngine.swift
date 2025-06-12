import Foundation

func getSuggestions(
    media: [MediaItem],
    user: UserPreferences,
    feedbackMap: [String: String]? = nil,
    liked: [String: Set<String>]? = nil,
    disliked: [String: Set<String>]? = nil,
    surprise: Bool = false
) -> [MediaItem] {
    // DEBUG: Print all media items before filtering
    print("[DEBUG] All media items (", media.count, "):")
    for item in media {
        print("[DEBUG] - \(item.title) | type: \(item.type) | genres: \(item.genres) | duration: \(item.duration) min")
    }
    // Enhanced pre-filter by time, format, genre, and mood
    let filtered: [MediaItem] = media.filter { item in
        // Enhanced time filter for TV shows
        if item.type == "show" {
            switch user.time {
            case "under_1h":
                if !(item.duration > 0 && item.duration <= 65) { return false }
            case "open":
                // For binge, include all shows
                break
            default:
                // For other time prefs, include all shows
                break
            }
        } else {
            // Movie logic as before
            let isShortEnough: Bool = {
                if user.time == "under_1h" {
                    return item.duration <= 65
                }
                // Add more time filters if needed
                return true
            }()
            let isCorrectFormat: Bool = {
                if user.format == "any" { return true }
                if user.format == "movie" { return item.type == "movie" }
                if user.format == "show" { return item.type == "show" }
                return true
            }()
            if !(isShortEnough && isCorrectFormat) { return false }
        }
        // Normalize genres for comparison
        let itemGenres = item.genres.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        let userGenres = user.genres.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        if !userGenres.isEmpty {
            if !itemGenres.contains(where: { userGenres.contains($0) }) {
                return false
            }
        }
        return true
    }
    // DEBUG: Print filtered items
    print("[DEBUG] Filtered items (", filtered.count, "):")
    for item in filtered {
        print("[DEBUG] - \(item.title) | type: \(item.type) | genres: \(item.genres) | duration: \(item.duration) min")
    }
    // Score and sort
    var scored: [(item: MediaItem, score: Int)] = filtered.map {
        var score = scoreItem($0, user: user, feedbackMap: feedbackMap, liked: liked, disliked: disliked, surprise: surprise)
        if user.time == "open", $0.type == "show" {
            if $0.viewCount == 0 { score += 10 }
            else if $0.viewCount < 3 { score += 5 }
        }
        return ($0, score)
    }
    scored = scored.filter { $0.score > -1000 } // Remove items penalized for wrong format
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

    // Fallback: if no recommendations, just return the filtered list (already matches genre/mood/format/time)
    if recommendations.isEmpty {
        recommendations = Array(filtered.prefix(3))
    }

    // Diversity: limit to one episode per show (keep highest-scoring episode per show)
    var seenShows = Set<String>()
    var diverse: [MediaItem] = []
    for (item, score) in scored {
        if user.format == "show" || user.format == "any" {
            if item.type == "show" {
                let showKey = item.seriesTitle?.lowercased() ?? item.title.lowercased()
                if seenShows.contains(showKey) { continue }
                seenShows.insert(showKey)
            }
        }
        diverse.append(item)
    }

    // Only return the top 3 results
    let topResults = Array(diverse.prefix(3))

    // Update lastRecommended for the top results
    let now = Date()
    var updatedTopResults: [MediaItem] = topResults.map { item in
        var mutableItem = item
        mutableItem.lastRecommended = now
        return mutableItem
    }

    // DEBUG: Print final recommendations and their scores
    print("[DEBUG] Final recommendations (", updatedTopResults.count, "):")
    for item in updatedTopResults {
        if let score = scored.first(where: { $0.item.id == item.id })?.score {
            print("[DEBUG] - \(item.title) | type: \(item.type) | score: \(score)")
        }
    }

    // DEBUG: Print top 10 scored movies for score distribution
    print("[DEBUG] Top 10 scored movies:")
    let top10 = scored.prefix(10)
    for (item, score) in top10 {
        print("[DEBUG] - \(item.title) | type: \(item.type) | score: \(score)")
    }

    return updatedTopResults
} 