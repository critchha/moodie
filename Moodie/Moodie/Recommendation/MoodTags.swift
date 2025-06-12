import Foundation

struct MoodDefinition {
    let genres: Set<String>
    let keywords: Set<String>
    let conflictingGenres: Set<String>?
}

let moodDefinitions: [String: MoodDefinition] = [
    "light_funny": MoodDefinition(
        genres: ["comedy", "family", "animation"],
        keywords: ["funny", "witty", "light", "humor", "hilarious", "feel-good", "uplifting", "charming", "quirky"],
        conflictingGenres: ["horror", "thriller", "war"]
    ),
    "intense": MoodDefinition(
        genres: ["action", "thriller", "crime", "war"],
        keywords: ["intense", "gripping", "suspense", "adrenaline", "high-stakes", "explosive", "danger", "chase", "battle"],
        conflictingGenres: ["animation", "family", "comedy"]
    ),
    "emotional": MoodDefinition(
        genres: ["drama", "romance"],
        keywords: ["emotional", "heartfelt", "poignant", "tearjerker", "moving", "touching", "love", "relationship", "loss"],
        conflictingGenres: ["action", "war", "horror"]
    ),
    "dramatic": MoodDefinition(
        genres: ["mystery", "history", "music", "fantasy", "science fiction"],
        keywords: ["dramatic", "twist", "mystery", "historical", "epic", "musical", "fantastical", "sci-fi", "imaginative", "legendary"],
        conflictingGenres: ["animation", "family", "comedy"]
    )
] 