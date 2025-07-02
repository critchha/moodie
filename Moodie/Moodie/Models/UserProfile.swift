import Foundation

struct UserProfile: Codable {
    let userId: String
    var preferences: UserPreferences
    var feedback: [Feedback] // thumbs up/down and watch feedback
    var watchHistory: [WatchRecord]
    var onboardingAnswers: OnboardingAnswers?
    var selectedServices: [String] = [] // e.g., ["Netflix", "Hulu"]

    // Memberwise initializer for manual construction
    init(
        userId: String,
        preferences: UserPreferences,
        feedback: [Feedback],
        watchHistory: [WatchRecord],
        onboardingAnswers: OnboardingAnswers?,
        selectedServices: [String] = []
    ) {
        self.userId = userId
        self.preferences = preferences
        self.feedback = feedback
        self.watchHistory = watchHistory
        self.onboardingAnswers = onboardingAnswers
        self.selectedServices = selectedServices
    }
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
    private var fileURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(filename)
    }
    func save(_ profile: UserProfile) {
        do {
            let data = try JSONEncoder().encode(profile)
            try data.write(to: fileURL)
            print("[UserProfileStore] Saved profile to \(fileURL.path)")
        } catch {
            print("[UserProfileStore] Failed to save profile: \(error)")
        }
    }
    func load() -> UserProfile {
        do {
            let data = try Data(contentsOf: fileURL)
            let profile = try JSONDecoder().decode(UserProfile.self, from: data)
            print("[UserProfileStore] Loaded profile from \(fileURL.path)")
            return profile
        } catch {
            print("[UserProfileStore] Failed to load profile: \(error)")
            let newProfile = UserProfile(userId: UUID().uuidString, preferences: UserPreferences(), feedback: [], watchHistory: [], onboardingAnswers: nil, selectedServices: [])
            save(newProfile)
            print("[UserProfileStore] Created and saved new default profile to \(fileURL.path)")
            return newProfile
        }
    }
} 