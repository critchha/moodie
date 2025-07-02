import Foundation

func scoreItem(
    _ item: MediaItem,
    user: UserPreferences,
    feedbackMap: [String: String]? = nil, // ["mediaId": "up"/"down"]
    liked: [String: Set<String>]? = nil,
    disliked: [String: Set<String>]? = nil,
    surprise: Bool = false
) -> Int {
    var score = 0
    let genres = item.genres.map { $0.lowercased() }
    let directors = Set(item.directors)
    let cast = Set(item.cast)
    
    // Comfort + Unwatched weighting
    if user.comfortMode {
        if item.viewCount >= 3 { score += 30 }
    } else if item.viewCount == 0 {
        score += 10
    }
    
    // Time fit
    if filterByTime(item, timePref: user.time) {
        score += 10
    } else {
        score += 5
    }
    
    // Mood match
    let userMoods = user.moods
    var moodTagsList: [String] = []
    for mood in userMoods {
        moodTagsList.append(contentsOf: moodTags[mood] ?? [])
    }
    if genres.contains(where: { moodTagsList.contains($0) }) {
        score += 10
    } else if moodTagsList.contains(where: { item.summary.lowercased().contains($0) }) {
        score += 5
    }
    
    // Genre match
    if !user.genres.isEmpty, genres.contains(where: { user.genres.contains($0) }) {
        score += 8
    }
    
    // Format match
    if filterByFormat(item, format: user.format) {
        score += 5
    }
    
    // Feedback adjustment
    if let feedbackMap = feedbackMap, let fb = feedbackMap[item.id] {
        if fb == "up" { score += 15 }
        else if fb == "down" { score -= 20 }
    }
    
    // Liked/disliked similarity
    if let liked = liked {
        if let likedGenres = liked["genres"], !likedGenres.isEmpty, genres.contains(where: { likedGenres.contains($0) }) {
            score += 6
        }
        if let likedDirectors = liked["directors"], !likedDirectors.isEmpty, !directors.isDisjoint(with: likedDirectors) {
            score += 4
        }
        if let likedCast = liked["cast"], !likedCast.isEmpty, !cast.isDisjoint(with: likedCast) {
            score += 2
        }
    }
    if let disliked = disliked {
        if let dislikedGenres = disliked["genres"], !dislikedGenres.isEmpty, genres.contains(where: { dislikedGenres.contains($0) }) {
            score -= 8
        }
        if let dislikedDirectors = disliked["directors"], !dislikedDirectors.isEmpty, !directors.isDisjoint(with: dislikedDirectors) {
            score -= 5
        }
        if let dislikedCast = disliked["cast"], !dislikedCast.isEmpty, !cast.isDisjoint(with: dislikedCast) {
            score -= 3
        }
    }
    
    // Surprise logic
    if surprise {
        score += Int.random(in: 0...5)
        if let liked = liked, let likedGenres = liked["genres"], !genres.contains(where: { likedGenres.contains($0) }) {
            score += Int.random(in: 0...8)
        }
    }
    
    return score
} 