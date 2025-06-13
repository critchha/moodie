import Foundation

struct UserProfile: Codable {
    let userId: String
    var preferences: UserPreferences
    var feedback: [Feedback] // thumbs up/down and watch feedback
    var watchHistory: [WatchRecord]
    var onboardingAnswers: OnboardingAnswers?
    var selectedServices: [String] = [] // e.g., ["Netflix", "Hulu"]
}

struct WatchRecord: Codable {
    let mediaId: String
    let watchedAt: Date
    let completed: Bool
    let durationWatched: Int // in minutes
}

struct OnboardingAnswers: Codable {
    var favoriteTitles: [String]
    var favoriteGenres: [String]
    var dislikedGenres: [String]
    var preferredContentType: String? // "movie", "show", "any"
    var preferredDuration: Int?
}

// Local persistence utility for UserProfile
class UserProfileStore {
    static let shared = UserProfileStore()
    private let filename = "userProfile.json"

    private var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    func save(_ profile: UserProfile) {
        do {
            let data = try JSONEncoder().encode(profile)
            try data.write(to: url)
        } catch {
            print("Failed to save user profile: \(error)")
        }
    }

    func load() -> UserProfile? {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(UserProfile.self, from: data)
        } catch {
            print("Failed to load user profile: \(error)")
            return nil
        }
    }
} 