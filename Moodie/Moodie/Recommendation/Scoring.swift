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
    let summaryLower = item.summary.lowercased()
    let randomBonus = Int.random(in: 1...5)
    let viewCount = item.viewCount
    let isShow = item.type == "show"
    let isMovie = item.type == "movie"
    let duration = item.duration
    let mediaId = item.id

    // Strict format filter
    if user.format == "movie" && !isMovie {
        score -= 1000
    } else if user.format == "show" && !isShow {
        score -= 1000
    } else if user.format == "any" {
        // If "any", both are allowed, no penalty/bonus
    }

    // Time-based scoring
    switch user.time {
    case "under_1h":
        if duration > 65 {
            score -= 30
        } else if duration <= 45 {
            score += 20
        } else if duration <= 60 {
            score += 10
        }
        if isShow && duration <= 65 {
            score += 10 // extra boost for short shows
        }
    case "1-2h":
        if duration >= 80 && duration <= 130 {
            score += 20
        } else if (duration >= 65 && duration < 80) || (duration > 130 && duration <= 150) {
            score += 10
        } else if duration < 65 || duration > 150 {
            score -= 10
        }
    case "2h+":
        if duration > 130 {
            score += 30
        } else if duration >= 110 && duration <= 130 {
            score += 10
        }
        // No penalty for <110 min
    default:
        break
    }

    // --- Granular Mood/Genre Scoring ---
    var genreMoodMatches = 0
    var allSelectedGenres: [String] = []
    if !user.genres.isEmpty {
        allSelectedGenres.append(contentsOf: user.genres.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
    }
    for mood in user.moods {
        if let moodDef = moodDefinitions[mood] {
            allSelectedGenres.append(contentsOf: moodDef.genres.map { $0.lowercased() })
        }
    }
    let uniqueSelectedGenres = Set(allSelectedGenres)
    let matchingGenres = genres.filter { uniqueSelectedGenres.contains($0) }
    genreMoodMatches = matchingGenres.count
    if genreMoodMatches > 0 {
        score += 10 // base bonus for at least one match
        score += (genreMoodMatches - 1) * 5 // +5 for each additional match
        if genreMoodMatches == uniqueSelectedGenres.count {
            score += 20 // big bonus for matching all selected genres/moods
        }
        // Penalty for only minimum match if more than one selected
        if genreMoodMatches == 1 && uniqueSelectedGenres.count > 1 {
            score -= 5 // small penalty for only matching one when more were selected
        }
    }

    // --- Unwatched/Low View Count ---
    if viewCount == 0 {
        score += 10
    } else if viewCount < 3 {
        score += 5
    }

    // --- Feedback/Personalization ---
    if let feedback = feedbackMap?[mediaId] {
        if feedback == "up" {
            score += 10
        } else if feedback == "down" {
            score -= 15
        }
    }

    // --- Summary Keyword Bonus ---
    for mood in user.moods {
        guard let moodDef = moodDefinitions[mood] else { continue }
        // Mood keyword in summary
        if moodDef.keywords.contains(where: { summaryLower.contains($0) }) {
            score += 5
        }
    }

    // --- Conflicting Genres ---
    for mood in user.moods {
        guard let moodDef = moodDefinitions[mood] else { continue }
        // Conflicting genre
        if let conflicts = moodDef.conflictingGenres {
            if genres.contains(where: { conflicts.contains($0) }) {
                score -= 10
            }
        }
    }

    // --- Feedback/Comfort/Other Logic (as before) ---
    if user.comfortMode {
        if viewCount >= 3 { score += 30 }
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

    // --- Penalize recently recommended items ---
    if let lastRecommended = item.lastRecommended {
        let daysSinceRecommended = Calendar.current.dateComponents([.day], from: lastRecommended, to: Date()).day ?? 999
        if daysSinceRecommended < 7 {
            score -= 15 // penalize if recommended in the last 7 days
        }
    }

    // --- Random bonus to break ties ---
    score += randomBonus // small random bonus to break ties
    return score
} 