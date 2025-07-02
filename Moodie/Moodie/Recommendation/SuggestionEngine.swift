import Foundation

struct BingeSuggestions {
    let movies: [MediaItem]
    let shows: [MediaItem]
}

enum SuggestionResult {
    case normal([MediaItem])
    case binge(BingeSuggestions)
}

func getSuggestions(
    media: [MediaItem],
    user: UserPreferences,
    feedbackMap: [String: String]? = nil,
    liked: [String: Set<String>]? = nil,
    disliked: [String: Set<String>]? = nil,
    surprise: Bool = false
<<<<<<< HEAD
) -> SuggestionResult {
    // Enhanced pre-filter by time, format, genre, and mood
=======
) -> [MediaItem] {
    // Pre-filter by time and format
>>>>>>> parent of 3509d10 (bug fixes to recommendation logic)
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
<<<<<<< HEAD
    // Score and sort
=======
>>>>>>> parent of 3509d10 (bug fixes to recommendation logic)
    var scored: [(item: MediaItem, score: Int)] = filtered.map {
        ($0, scoreItem($0, user: user, feedbackMap: feedbackMap, liked: liked, disliked: disliked, surprise: surprise))
    }
    scored = scored.filter { $0.score > 0 }
    scored.sort { $0.score > $1.score }
<<<<<<< HEAD

    // --- Binge Worthy Mode ---
    if user.time == "open" {
        // Movies: group by seriesTitle, prioritize franchises with >1 movie
        let movieItems = scored.map { $0.item }.filter { $0.type == "movie" }
        let movieFranchises = Dictionary(grouping: movieItems, by: { $0.seriesTitle?.lowercased() ?? $0.title.lowercased() })
        let franchiseMovies = movieFranchises.values.filter { $0.count > 1 }
        // Pick the highest scored movie from each franchise
        var franchiseMoviePicks: [MediaItem] = []
        for group in franchiseMovies {
            if let best = group.max(by: { a, b in
                let sa = scored.first(where: { $0.item.id == a.id })?.score ?? 0
                let sb = scored.first(where: { $0.item.id == b.id })?.score ?? 0
                return sa < sb
            }) {
                franchiseMoviePicks.append(best)
            }
        }
        // Sort by score and pick top 3
        var topFranchiseMovies = franchiseMoviePicks.sorted { a, b in
            let sa = scored.first(where: { $0.item.id == a.id })?.score ?? 0
            let sb = scored.first(where: { $0.item.id == b.id })?.score ?? 0
            return sa > sb
        }
        // If fewer than 3, fill with top standalone movies
        if topFranchiseMovies.count < 3 {
            let franchiseIds = Set(topFranchiseMovies.map { $0.id })
            let standaloneMovies = movieItems.filter { !franchiseIds.contains($0.id) }
            let topStandalone = standaloneMovies.sorted { a, b in
                let sa = scored.first(where: { $0.item.id == a.id })?.score ?? 0
                let sb = scored.first(where: { $0.item.id == b.id })?.score ?? 0
                return sa > sb
            }
            let needed = 3 - topFranchiseMovies.count
            if !topStandalone.isEmpty {
                topFranchiseMovies.append(contentsOf: topStandalone.prefix(needed))
            }
        }
        let topMovies = Array(topFranchiseMovies.prefix(3))

        // TV Shows: one per show (highest scored episode per show)
        // let showItems = scored.map { $0.item }.filter { $0.type == "show" } // Removed unused variable
        var seenShows = Set<String>()
        var topShows: [MediaItem] = []
        for (item, _) in scored where item.type == "show" {
            let showKey = item.seriesTitle?.lowercased() ?? item.title.lowercased()
            if seenShows.contains(showKey) { continue }
            seenShows.insert(showKey)
            topShows.append(item)
            if topShows.count >= 3 { break }
        }
        if topShows.count < 3 {
        }

        // Update lastRecommended for the top results
        let now = Date()
        let updatedMovies = topMovies.map { item in
            var mutableItem = item
            mutableItem.lastRecommended = now
            return mutableItem
        }
        let updatedShows = topShows.map { item in
            var mutableItem = item
            mutableItem.lastRecommended = now
            return mutableItem
        }

        return .binge(BingeSuggestions(movies: Array(updatedMovies), shows: Array(updatedShows)))
    }

    // --- Normal Mode ---
=======
    
>>>>>>> parent of 3509d10 (bug fixes to recommendation logic)
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
<<<<<<< HEAD

    // Diversity: limit to one episode per show (keep highest-scoring episode per show)
    var seenShows = Set<String>()
    var diverse: [MediaItem] = []
    for (item, _) in scored {
        if user.format == "movie" && item.type != "movie" {
            continue // skip non-movies if movie is selected
        }
        if user.format == "show" && item.type != "show" {
            continue // skip non-shows if show is selected
        }
        if (user.format == "show" || user.format == "any") && item.type == "show" {
            let showKey = item.seriesTitle?.lowercased() ?? item.title.lowercased()
            if seenShows.contains(showKey) { continue }
            seenShows.insert(showKey)
        }
        diverse.append(item)
    }

    // Only return the top 3 results
    let topResults = Array(diverse.prefix(3))

    // Update lastRecommended for the top results
    let now = Date()
    let updatedTopResults: [MediaItem] = topResults.map { item in
        var mutableItem = item
        mutableItem.lastRecommended = now
        return mutableItem
    }

    return .normal(updatedTopResults)
=======
    
    return recommendations
>>>>>>> parent of 3509d10 (bug fixes to recommendation logic)
} 