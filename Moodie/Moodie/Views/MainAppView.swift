import SwiftUI
import Foundation

struct MainAppView: View {
    // Time options
    let timeOptions: [(label: String, value: String)] = [
        (label: "Less than an hour", value: "under_1h"),
        (label: "1–2 hours", value: "1_2h"),
        (label: "2+ hours", value: "2plus"),
        (label: "Open-ended / binge", value: "open")
    ]
    // Mood options
    let moodOptions: [(label: String, value: String)] = [
        (label: "😀 Light and funny", value: "light_funny"),
        (label: "💥 Intense", value: "intense"),
        (label: "😭 Emotional", value: "emotional"),
        (label: "🎭 Dramatic", value: "dramatic")
    ]
    // Format options
    let formatOptions: [(label: String, value: String)] = [
        (label: "Movie", value: "movie"),
        (label: "TV show", value: "show"),
        (label: "Any", value: "any")
    ]
    // Genre options
    let genreOptions: [(label: String, value: String)] = [
        (label: "Action", value: "action"),
        (label: "Comedy", value: "comedy"),
        (label: "Drama", value: "drama"),
        (label: "Family", value: "family"),
        (label: "Animation", value: "animation"),
        (label: "Thriller", value: "thriller"),
        (label: "Crime", value: "crime"),
        (label: "Romance", value: "romance"),
        (label: "Biography", value: "biography"),
        (label: "Musical", value: "musical"),
        (label: "Mystery", value: "mystery"),
        (label: "Historical", value: "historical")
    ]
    
    @State private var selectedTime = "1_2h"
    @State private var selectedMoods: Set<String> = ["light_funny"]
    @State private var selectedFormat = "any"
    @State private var selectedGenres: Set<String> = []
    @State private var comfortMode = false
    @State private var surprisePick = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var recommendations: SuggestionResult? = nil
    @State private var recommendationsToShow: Int = 10
    @State private var feedback: [String: FeedbackType] = [:] // Feedback keyed by MediaItem id
    @State private var mediaLibrary: [MediaItem] = []
    @State private var isLibraryLoading = false
    @State private var libraryError: String?
    @State private var showOnboarding = false
    @State private var userProfile: UserProfile? = nil
    @State private var rejectedRecommendationIDs: Set<String> = []
    @State private var flixPatrolItems: [MediaItem] = []
    
    var timePickerOptions: [PickerOption] {
        timeOptions.map { PickerOption(label: $0.label, value: $0.value) }
    }
    
    var moodPickerOptions: [PickerOption] {
        moodOptions.map { PickerOption(label: $0.label, value: $0.value) }
    }
    
    var formatPickerOptions: [PickerOption] {
        formatOptions.map { PickerOption(label: $0.label, value: $0.value) }
    }
    
    var genrePickerOptions: [PickerOption] {
        genreOptions.map { PickerOption(label: $0.label, value: $0.value) }
    }

    var body: some View {
        // Compute merged and filtered recommendations outside the Form
        let visibleRecs: [MediaItem] = {
            guard let profile = userProfile, !profile.selectedServices.isEmpty else { return [] }
            let usePlex = profile.selectedServices.contains("Plex")
            let flixServices = profile.selectedServices.filter { $0 != "Plex" }
            var mergedItems: [String: MediaItem] = [:]
            if usePlex, let recs = recommendations {
                let plexItems: [MediaItem]
                switch recs {
                case .normal(let items):
                    plexItems = items
                case .binge(let binge):
                    plexItems = binge.movies + binge.shows
                }
                for item in plexItems {
                    mergedItems[item.id] = item
                }
            }
            for item in FlixPatrolService.shared.dedupedItems(for: flixServices) {
                if var existing = mergedItems[item.id] {
                    for platform in item.platforms where !existing.platforms.contains(platform) {
                        existing.platforms.append(platform)
                    }
                    mergedItems[item.id] = existing
                } else {
                    mergedItems[item.id] = item
                }
            }
            let allRecs = Array(mergedItems.values)
            return allRecs.filter { !rejectedRecommendationIDs.contains($0.id) }
        }()
        NavigationView {
            Form {
                TimeSection(options: timePickerOptions, selectedTime: $selectedTime)
                MoodSection(options: moodPickerOptions, selectedMoods: $selectedMoods)
                FormatSection(options: formatPickerOptions, selectedFormat: $selectedFormat)
                GenreSection(options: genrePickerOptions, selectedGenres: $selectedGenres)
                TogglesSection(comfortMode: $comfortMode, surprisePick: $surprisePick)
                PlexLibrarySectionView(
                    isLibraryLoading: isLibraryLoading,
                    libraryError: libraryError,
                    mediaLibrary: mediaLibrary,
                    fetchLibrary: fetchLibrary
                )
                Section {
                    Button(action: getRecommendations) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Get Recommendations")
                                .font(.headline)
                        }
                    }
                    .disabled(isLoading)
                }
                // Only show RecommendationsSection if there are recommendations
                if !visibleRecs.isEmpty {
                    RecommendationsSection(
                        title: "Top 10 Recommendations",
                        recommendations: Array(visibleRecs.prefix(recommendationsToShow)),
                        feedback: feedback,
                        userProfile: userProfile,
                        onFeedback: { rec, type in
                            feedback[rec.id] = type
                            if type == .down {
                                rejectedRecommendationIDs.insert(rec.id)
                                if visibleRecs.count > recommendationsToShow {
                                    recommendationsToShow += 1
                                }
                            }
                        },
                        onStarRating: { _,_ in },
                        onMarkWatched: { _ in },
                        onRemoveFeedback: { _ in },
                        isLoading: isLoading,
                        errorMessage: errorMessage,
                        showWatchOn: true
                    )
                }
            }
            .navigationTitle("Moodie")
            .onAppear {
                if mediaLibrary.isEmpty { fetchLibrary() }
                if let profile = UserProfileStore.shared.load() {
                    userProfile = profile
                    // FlixPatrol: refresh cache and load deduped items
                    FlixPatrolService.shared.refreshAllCachesIfNeeded(for: profile.selectedServices) {
                        flixPatrolItems = FlixPatrolService.shared.dedupedItems(for: profile.selectedServices)
                    }
                } else {
                    showOnboarding = true
                }
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingFlowView(onComplete: { profile in
                    UserProfileStore.shared.save(profile)
                    userProfile = profile
                    showOnboarding = false
                })
            }
        }
    }
    
    private func fetchLibrary() {
        isLibraryLoading = true
        libraryError = nil
        PlexService.shared.fetchMediaLibrary { result in
            DispatchQueue.main.async {
                isLibraryLoading = false
                switch result {
                case .success(let items):
                    mediaLibrary = items
                case .failure(let error):
                    libraryError = error.localizedDescription
                }
            }
        }
    }
    
    private func getRecommendations() {
        isLoading = true
        errorMessage = nil
        recommendations = nil
        recommendationsToShow = 10 // Reset to 10 on new fetch
        // Always use current UI state for userPrefs
        let userPrefs = UserPreferences(
            time: selectedTime,
            moods: Array(selectedMoods),
            genres: Array(selectedGenres),
            format: selectedFormat,
            comfortMode: comfortMode,
            surprise: surprisePick
        )
        var feedbackMap: [String: String]? = nil
        let liked: [String: Set<String>]? = nil
        let disliked: [String: Set<String>]? = nil
        if let profile = userProfile {
            // Build feedbackMap: [mediaId: "up"/"down"]
            feedbackMap = [:]
            for fb in profile.feedback {
                if fb.rating >= 4 || fb.wouldWatchAgain {
                    feedbackMap?[fb.mediaId] = "up"
                } else if fb.rating <= 2 && !fb.wouldWatchAgain {
                    feedbackMap?[fb.mediaId] = "down"
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
            let allRecs = getSuggestions(
                media: mediaLibrary,
                user: userPrefs,
                feedbackMap: feedbackMap,
                liked: liked,
                disliked: disliked,
                surprise: userPrefs.surprise
            )
            recommendations = allRecs
            recommendationsToShow = 10 // Reset to 10 on new fetch
        }
    }
}

struct MultipleSelectionRow: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .foregroundColor(.primary)
    }
}

enum FeedbackType {
    case up, down
}

struct RecommendationCard: View {
    let rec: MediaItem
    let feedback: FeedbackType?
    let starRating: Int
    let watchedToCompletion: Bool
    let onFeedback: (FeedbackType) -> Void
    let onStarRating: (Int) -> Void
    let onMarkWatched: () -> Void
    let onRemoveFeedback: () -> Void
    @State private var showThanks: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let posterURL = rec.posterURL, let url = URL(string: posterURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 120, height: 180)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 120, maxHeight: 180)
                            .cornerRadius(12)
                    case .failure:
                        Image(systemName: "film")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 120)
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            HStack {
                Text(rec.title)
                    .font(.headline)
                Spacer()
                Text(rec.type.capitalized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Text(rec.genres.map { $0.capitalized }.joined(separator: ", "))
                .font(.subheadline)
                .foregroundColor(.secondary)
            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                Text("\(rec.duration) min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if !rec.summary.isEmpty {
                Text(rec.summary)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(3)
            }
            HStack(spacing: 8) {
                ForEach(1...5, id: \ .self) { star in
                    Image(systemName: star <= starRating ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                        .onTapGesture { onStarRating(star) }
                }
                Spacer()
                if watchedToCompletion {
                    Text("Watched")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Button("Mark as Watched", action: onMarkWatched)
                        .font(.caption)
                }
            }
            HStack(spacing: 24) {
                Button(action: {
                    onFeedback(.up)
                    showThanks = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { showThanks = false }
                }) {
                    Image(systemName: feedback == .up ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .foregroundColor(feedback == .up ? .green : .gray)
                        .font(.title2)
                        .background(
                            Circle()
                                .fill(feedback == .up ? Color.green.opacity(0.2) : Color.clear)
                                .frame(width: 40, height: 40)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                Button(action: {
                    onFeedback(.down)
                    showThanks = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { showThanks = false }
                }) {
                    Image(systemName: feedback == .down ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .foregroundColor(feedback == .down ? .red : .gray)
                        .font(.title2)
                        .background(
                            Circle()
                                .fill(feedback == .down ? Color.red.opacity(0.2) : Color.clear)
                                .frame(width: 40, height: 40)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                Button("Remove Feedback", action: onRemoveFeedback)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .padding(.top, 8)
            if showThanks || feedback != nil {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.accentColor)
                    Text("Thanks for your feedback!")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                .transition(.opacity)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color(.black).opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct MoodSelectionRow: View {
    let options: [PickerOption]
    @Binding var selectedMoods: Set<String>
    var body: some View {
        ForEach(options) { option in
            MultipleSelectionRow(
                label: option.label,
                isSelected: selectedMoods.contains(option.value)
            ) {
                if selectedMoods.contains(option.value) {
                    selectedMoods.remove(option.value)
                } else {
                    selectedMoods.insert(option.value)
                }
            }
        }
    }
}

struct FormatPickerRow: View {
    let options: [PickerOption]
    @Binding var selectedFormat: String
    var body: some View {
        Picker("Format", selection: $selectedFormat) {
            ForEach(options) { option in
                Text(option.label).tag(option.value)
            }
        }
        .pickerStyle(.segmented)
    }
}

struct TimePickerRow: View {
    let options: [PickerOption]
    @Binding var selectedTime: String
    var body: some View {
        Picker("Time", selection: $selectedTime) {
            ForEach(options) { option in
                Text(option.label).tag(option.value)
            }
        }
        .pickerStyle(.menu)
    }
}

struct TimeSection: View {
    let options: [PickerOption]
    @Binding var selectedTime: String
    var body: some View {
        Section(header: Text("Time Available")) {
            TimePickerRow(options: options, selectedTime: $selectedTime)
        }
    }
}

struct MoodSection: View {
    let options: [PickerOption]
    @Binding var selectedMoods: Set<String>
    var body: some View {
        Section(header: Text("Mood (Select one or more)")) {
            MoodSelectionRow(options: options, selectedMoods: $selectedMoods)
        }
    }
}

struct FormatSection: View {
    let options: [PickerOption]
    @Binding var selectedFormat: String
    var body: some View {
        Section(header: Text("Format")) {
            FormatPickerRow(options: options, selectedFormat: $selectedFormat)
        }
    }
}

struct GenreSection: View {
    let options: [PickerOption]
    @Binding var selectedGenres: Set<String>
    var body: some View {
        Section(header: Text("Genres (Select any)")) {
            GenreChipRow(options: options, selectedGenres: $selectedGenres)
        }
    }
}

struct TogglesSection: View {
    @Binding var comfortMode: Bool
    @Binding var surprisePick: Bool
    var body: some View {
        Section {
            Toggle("Comfort Mode (Rewatch-friendly)", isOn: $comfortMode)
            Toggle("Surprise Pick (Wildcard)", isOn: $surprisePick)
        }
    }
}

struct PlexLibrarySectionView: View {
    let isLibraryLoading: Bool
    let libraryError: String?
    let mediaLibrary: [MediaItem]
    let fetchLibrary: () -> Void
    var body: some View {
        Section(header: Text("Plex Library")) {
            if isLibraryLoading {
                ProgressView("Loading your Plex library...")
            } else if let libraryError = libraryError {
                Text("Error: \(libraryError)")
                    .foregroundColor(.red)
                Button("Retry") { fetchLibrary() }
            } else if mediaLibrary.isEmpty {
                Text("No media found in your Plex library.")
                    .foregroundColor(.secondary)
                Button("Reload Library") { fetchLibrary() }
            } else {
                Text("Loaded \(mediaLibrary.count) items from Plex.")
                    .foregroundColor(.secondary)
                Button("Reload Library") { fetchLibrary() }
            }
        }
    }
}

struct RecommendationsSection: View {
    let title: String
    let recommendations: [MediaItem]
    let feedback: [String: FeedbackType]
    let userProfile: UserProfile?
    let onFeedback: (MediaItem, FeedbackType) -> Void
    let onStarRating: (MediaItem, Int) -> Void
    let onMarkWatched: (MediaItem) -> Void
    let onRemoveFeedback: (MediaItem) -> Void
    let isLoading: Bool
    let errorMessage: String?
    let showWatchOn: Bool
    var body: some View {
        Section(header: Text(title)) {
            if isLoading {
                ProgressView("Loading recommendations...")
                    .padding()
            } else if !recommendations.isEmpty {
                ForEach(recommendations) { rec in
                    let currentFeedback = userProfile?.feedback.first(where: { $0.mediaId == rec.id })
                    VStack(alignment: .leading, spacing: 8) {
                        RecommendationCard(
                            rec: rec,
                            feedback: feedback[rec.id],
                            starRating: currentFeedback?.rating ?? 0,
                            watchedToCompletion: currentFeedback?.watchedToCompletion ?? false,
                            onFeedback: { type in onFeedback(rec, type) },
                            onStarRating: { rating in onStarRating(rec, rating) },
                            onMarkWatched: { onMarkWatched(rec) },
                            onRemoveFeedback: { onRemoveFeedback(rec) }
                        )
                        if showWatchOn {
                            HStack(spacing: 8) {
                                ForEach(rec.platformURLs(), id: \ .0) { (platform, url) in
                                    if let url = url {
                                        Link("Watch on \(platform)", destination: url)
                                            .font(.caption)
                                            .padding(6)
                                            .background(Color.accentColor.opacity(0.1))
                                            .cornerRadius(8)
                                    } else {
                                        Text(platform)
                                            .font(.caption)
                                            .padding(6)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text("No recommendations yet. Fill out the form and tap 'Get Recommendations'.")
                    .foregroundColor(.secondary)
                    .padding(.vertical)
            }
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
    }
}

#Preview {
    MainAppView()
}

// Add helper for platform URLs
extension MediaItem {
    func platformURLs() -> [(String, URL?)] {
        platforms.map { platform in
            switch platform {
            case "Plex":
                // Custom URL scheme or local playback
                return ("Plex", URL(string: "plex://"))
            case "Netflix":
                return ("Netflix", URL(string: "https://www.netflix.com/search?q=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"))
            case "Hulu":
                return ("Hulu", URL(string: "https://www.hulu.com/search?q=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"))
            case "HBO":
                return ("HBO", URL(string: "https://play.max.com/search?q=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"))
            case "Paramount+":
                return ("Paramount+", URL(string: "https://www.paramountplus.com/search/t/\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"))
            case "Apple TV+":
                return ("Apple TV+", URL(string: "https://tv.apple.com/us/search/\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"))
            case "Disney+":
                return ("Disney+", URL(string: "https://www.disneyplus.com/search/\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"))
            default:
                return (platform, nil)
            }
        }
    }
} 