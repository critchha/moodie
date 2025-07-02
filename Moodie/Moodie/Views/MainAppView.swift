import SwiftUI
import Foundation
import Combine

struct MainAppView: View {
    let initialUserProfile: UserProfile
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
    @State private var userProfile: UserProfile?
    @State private var rejectedRecommendationIDs: Set<String> = []
    @State private var watchmodeItems: [MediaItem] = []
    @AppStorage("isOnboarded") private var isOnboarded: Bool = true
    @State private var tmdbTrendingTitles: [TMDBTrendingTitle] = []
    @State private var showResetSheet = false
    @State private var resetMode: ResetMode? = nil
    @State private var showOnboardingMessage = false
    @State private var showPlexAuthMessage = false
    enum ResetMode { case streaming, preferences, all }
    
    init(userProfile: UserProfile) {
        self.initialUserProfile = userProfile
        _userProfile = State(initialValue: userProfile)
    }
    
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
        VStack {
            if showOnboardingMessage {
                Text("Please complete onboarding to get recommendations.")
                    .foregroundColor(.red)
            }
            if showPlexAuthMessage {
                Text("Plex is selected but not authenticated. Please sign in to Plex.")
                    .foregroundColor(.orange)
            }
            // Compute merged and filtered recommendations outside the Form
            let visibleRecs: [MediaItem] = {
                if let recs = recommendations, let profile = userProfile {
                    let selectedServices = Set(profile.selectedServices.map { $0.lowercased() })
                    let filterByService: (MediaItem) -> Bool = { item in
                        let itemPlatforms = item.platforms.map { $0.lowercased() }
                        if itemPlatforms.isEmpty || itemPlatforms.contains(where: { $0.isEmpty }) {
                            return true
                        }
                        return !selectedServices.isDisjoint(with: itemPlatforms)
                    }
                    let preferredType = profile.onboardingAnswers?.preferredContentType ?? "movie"
                    let isBinge = selectedTime == "open"
                    switch recs {
                    case .normal(let items):
                        let filtered = items.filter { filterByService($0) && !rejectedRecommendationIDs.contains($0.id) }
                        if isBinge {
                            // Binge: balance between movie franchises and TV series
                            let movies = filtered.filter { $0.type == "movie" }
                            let shows = filtered.filter { $0.type == "show" }
                            let movieFranchises = Dictionary(grouping: movies, by: { $0.seriesTitle?.lowercased() ?? $0.title.lowercased() })
                            let franchiseMovies = movieFranchises.values.filter { $0.count > 1 }
                            var franchiseMoviePicks: [MediaItem] = []
                            for group in franchiseMovies {
                                if let best = group.first { franchiseMoviePicks.append(best) }
                            }
                            let topMovies = Array(franchiseMoviePicks.prefix(5))
                            let topShows = Array(shows.prefix(5))
                            return (topMovies + topShows)
                        } else {
                            // Only show user's firm choice, but apply penalty to in-theater movies
                            let preferred = filtered.filter { $0.type == preferredType }
                            // Score and sort, penalize in-theater
                            let scored = preferred.map { item -> (MediaItem, Int) in
                                var score = 0
                                if let isInTheaters = item.isInTheaters, isInTheaters {
                                    score -= 10 // light penalty
                                }
                                return (item, score)
                            }
                            // Sort by penalty (and fallback to original order)
                            let sorted = scored.sorted { $0.1 > $1.1 }.map { $0.0 }
                            let top10 = Array(sorted.prefix(10))
                            // Find best in-theater movie not in top 10
                            if let inTheater = sorted.first(where: { ($0.isInTheaters ?? false) && !top10.contains(where: { $0.id == $0.id }) }) {
                                return top10 + [inTheater]
                            } else {
                                return top10
                            }
                        }
                    case .binge(let binge):
                        let all = (binge.movies + binge.shows).filter { filterByService($0) && !rejectedRecommendationIDs.contains($0.id) }
                        if isBinge {
                            let movies = all.filter { $0.type == "movie" }
                            let shows = all.filter { $0.type == "show" }
                            let movieFranchises = Dictionary(grouping: movies, by: { $0.seriesTitle?.lowercased() ?? $0.title.lowercased() })
                            let franchiseMovies = movieFranchises.values.filter { $0.count > 1 }
                            var franchiseMoviePicks: [MediaItem] = []
                            for group in franchiseMovies {
                                if let best = group.first { franchiseMoviePicks.append(best) }
                            }
                            let topMovies = Array(franchiseMoviePicks.prefix(5))
                            let topShows = Array(shows.prefix(5))
                            return (topMovies + topShows)
                        } else {
                            return all.filter { $0.type == preferredType }
                        }
                    }
                }
                return []
            }()
            NavigationView {
                Form {
                    TimeSection(options: timePickerOptions, selectedTime: $selectedTime)
                    MoodSection(options: moodPickerOptions, selectedMoods: $selectedMoods)
                    FormatSection(options: formatPickerOptions, selectedFormat: $selectedFormat)
                    GenreSection(options: genrePickerOptions, selectedGenres: $selectedGenres)
                    TogglesSection(comfortMode: $comfortMode, surprisePick: $surprisePick)
                    // Only show Plex library if user selected Plex
                    if let profile = userProfile, profile.selectedServices.contains("Plex") {
                        PlexLibrarySectionView(
                            isLibraryLoading: isLibraryLoading,
                            libraryError: libraryError,
                            mediaLibrary: mediaLibrary,
                            fetchLibrary: fetchLibrary
                        )
                    }
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
                                    // Always keep 10 visible
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
                    Section {
                        Button(action: { showResetSheet = true }) {
                            Text("Reset Settings")
                                .foregroundColor(.red)
                        }
                        .actionSheet(isPresented: $showResetSheet) {
                            ActionSheet(title: Text("Reset Settings"), message: Text("What would you like to reset?"), buttons: [
                                .default(Text("Reset Streaming Providers")) { resetMode = .streaming },
                                .default(Text("Reset Preferences")) { resetMode = .preferences },
                                .destructive(Text("Reset All")) { resetMode = .all },
                                .cancel()
                            ])
                        }
                    }
                    Section(header: Text("Trending Now")) {
                        let _ = { print("[TrendingNow] tmdbTrendingTitles count: \(tmdbTrendingTitles.count)") }()
                        if tmdbTrendingTitles.isEmpty {
                            Text("No trending results found.")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(tmdbTrendingTitles) { item in
                                let _ = { print("[TrendingNow] id=\(item.id), title=\(item.title), type=\(item.type), genres=\(item.genres), platforms=\(item.streamingPlatforms)") }()
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.title)
                                        .font(.headline)
                                    HStack(spacing: 12) {
                                        Text(item.type.capitalized)
                                        if let runtime = item.runtime {
                                            Text("\(runtime) min")
                                        }
                                    }
                                    if !item.genres.isEmpty {
                                        Text("Genres: " + item.genres.joined(separator: ", "))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    if !item.streamingPlatforms.isEmpty {
                                        Text("Platforms: " + item.streamingPlatforms.joined(separator: ", "))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    if let isInTheaters = item.isInTheaters, isInTheaters, item.streamingPlatforms.isEmpty {
                                        Text("In Theaters")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                            .padding(.vertical, 2)
                                    }
                                    Text(item.overview)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .lineLimit(3)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Moodie")
            .onAppear {
                var loadedProfile = UserProfileStore.shared.load()
                if loadedProfile == nil {
                    print("[MainAppView] No user profile found, creating default profile.")
                    let defaultProfile = UserProfile(
                        userId: UUID().uuidString,
                        preferences: UserPreferences(time: "any", moods: [], genres: [], format: "any", comfortMode: false, surprise: false),
                        feedback: [],
                        watchHistory: [],
                        onboardingAnswers: nil,
                        selectedServices: []
                    )
                    UserProfileStore.shared.save(defaultProfile)
                    loadedProfile = defaultProfile
                }
                userProfile = loadedProfile
                // Fetch trending titles from TMDB
                TMDBService.shared.fetchTrending { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let titles):
                            tmdbTrendingTitles = titles
                            print("[MainAppView] TMDB Trending titles count: \(titles.count)")
                            for t in titles.prefix(5) {
                                print("\(t.title) (\(t.type)), duration: \(t.runtime ?? 0), genres: \(t.genres), platforms: \(t.streamingPlatforms), overview: \(t.overview)")
                            }
                        case .failure(let error):
                            print("[MainAppView] Failed to fetch TMDB trending titles: \(error)")
                        }
                    }
                }
                if mediaLibrary.isEmpty, let profile = userProfile, profile.selectedServices.contains("Plex") {
                    fetchLibrary()
                }
                let profile = UserProfileStore.shared.load()
                if profile.selectedServices.isEmpty {
                    showOnboardingMessage = true
                } else {
                    showOnboardingMessage = false
                }
                if profile.selectedServices.contains("Plex") && !PlexService.shared.isAuthenticated {
                    showPlexAuthMessage = true
                } else {
                    showPlexAuthMessage = false
                }
            }
            // Onboarding sheet
            .sheet(isPresented: Binding(
                get: { !isOnboarded || resetMode != nil },
                set: { newValue in
                    if newValue == false { resetMode = nil; isOnboarded = true }
                }
            )) {
                if !isOnboarded || resetMode == .all {
                    // Full onboarding
                    OnboardingFlowView(onComplete: { profile in
                        print("[MainAppView] Onboarding completed. Saving profile and checking Plex.")
                        userProfile = profile
                        UserProfileStore.shared.save(profile)
                        isOnboarded = true
                        resetMode = nil
                        if profile.selectedServices.contains("Plex") {
                            fetchLibrary()
                        }
                    })
                } else if resetMode == .streaming {
                    // Only streaming providers
                    OnboardingFlowView(onComplete: { profile in
                        // Update only selectedServices, preserve other fields
                        if var current = userProfile {
                            current.selectedServices = profile.selectedServices
                            userProfile = current
                            UserProfileStore.shared.save(current)
                            if profile.selectedServices.contains("Plex") {
                                print("[Onboarding] Plex selected, fetching library after streaming reset.")
                                fetchLibrary()
                            }
                        } else {
                            userProfile = profile
                            UserProfileStore.shared.save(profile)
                            if profile.selectedServices.contains("Plex") {
                                print("[Onboarding] Plex selected, fetching library after streaming reset (no current profile).")
                                fetchLibrary()
                            }
                        }
                        resetMode = nil
                    }, onlyStreaming: true)
                } else if resetMode == .preferences {
                    // Only preferences
                    OnboardingFlowView(onComplete: { profile in
                        // Update only onboardingAnswers and preferences, preserve selectedServices
                        if var current = userProfile {
                            current.onboardingAnswers = profile.onboardingAnswers
                            current.preferences = profile.preferences
                            userProfile = current
                            UserProfileStore.shared.save(current)
                        } else {
                            userProfile = profile
                            UserProfileStore.shared.save(profile)
                        }
                        if (userProfile?.selectedServices.contains("Plex") ?? false) {
                            print("[Onboarding] Plex selected, fetching library after preferences reset.")
                            fetchLibrary()
                        }
                        resetMode = nil
                    }, onlyPreferences: true)
                }
            }
            .onChange(of: selectedTime) { clearRecommendations() }
            .onChange(of: selectedMoods) { clearRecommendations() }
            .onChange(of: selectedGenres) { clearRecommendations() }
            .onChange(of: selectedFormat) { clearRecommendations() }
            .onChange(of: comfortMode) { clearRecommendations() }
            .onChange(of: surprisePick) { clearRecommendations() }
        }
    }
    
    private func fetchLibrary() {
        print("[fetchLibrary] Called fetchLibrary() with userProfile.selectedServices: \(userProfile?.selectedServices ?? [])")
        isLibraryLoading = true
        libraryError = nil
        PlexService.shared.fetchMediaLibrary { result in
            DispatchQueue.main.async {
                isLibraryLoading = false
                switch result {
                case .success(let items):
                    print("[fetchLibrary] Loaded \(items.count) items from Plex.")
                    mediaLibrary = items
                case .failure(let error):
                    print("[fetchLibrary] Error loading Plex library: \(error.localizedDescription)")
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
        let liked: [String: Set<String>] = [:]
        let disliked: [String: Set<String>] = [:]
        print("[getRecommendations] Plex mediaLibrary count: \(mediaLibrary.count)")
        if !mediaLibrary.isEmpty { print("[getRecommendations] Plex first: \(mediaLibrary[0])") }
        print("[getRecommendations] tmdbTrendingTitles count: \(tmdbTrendingTitles.count)")
        if !tmdbTrendingTitles.isEmpty { print("[getRecommendations] tmdbTrendingTitles first: \(tmdbTrendingTitles[0])") }
        // Merge and deduplicate Plex and TMDB items by title (case-insensitive)
        var plexByTitle = [String: MediaItem]()
        for item in mediaLibrary {
            plexByTitle[item.title.lowercased()] = item
        }
        var merged: [MediaItem] = []
        // Add Plex items first
        merged.append(contentsOf: plexByTitle.values)
        // For TMDB, merge metadata if Plex exists, else add as new
        for tmdb in tmdbTrendingTitles.map({ $0.toMediaItem() }) {
            let key = tmdb.title.lowercased()
            if var plexItem = plexByTitle[key] {
                // Merge: prefer Plex for playback/platform, TMDB for poster/overview/genres if missing
                if plexItem.posterURL == nil, let poster = tmdb.posterURL { plexItem.posterURL = poster }
                if plexItem.summary.isEmpty, !tmdb.summary.isEmpty { plexItem.summary = tmdb.summary }
                if plexItem.genres.isEmpty, !tmdb.genres.isEmpty { plexItem.genres = tmdb.genres }
                if plexItem.platforms.isEmpty, !tmdb.platforms.isEmpty { plexItem.platforms = tmdb.platforms + ["Plex"] }
                merged.removeAll { $0.title.lowercased() == key }
                merged.append(plexItem)
            } else {
                merged.append(tmdb)
            }
        }
        print("[getRecommendations] merged items count: \(merged.count)")
        if !merged.isEmpty { print("[getRecommendations] merged first: \(merged[0])") }
        // Filtering (if any)
        let filtered = merged.filter { _ in true }
        print("[getRecommendations] filtered recommendations count: \(filtered.count)")
        if !filtered.isEmpty { print("[getRecommendations] filtered first: \(filtered[0])") }
        recommendations = .normal(filtered)
        isLoading = false
    }
    
    private func clearRecommendations() {
        recommendations = nil
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
            if let isInTheaters = rec.isInTheaters, isInTheaters, rec.platforms.isEmpty {
                Text("In Theaters")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.vertical, 2)
            }
            if !rec.platforms.isEmpty {
                HStack(spacing: 8) {
                    Text("Watch on:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    ForEach(rec.platforms, id: \.self) { platform in
                        Text(platform)
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                    }
                }
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
                Button("Reload Library") {
                    print("[MainAppView] Reload Plex Library pressed.")
                    fetchLibrary()
                }
            } else {
                Text("Loaded \(mediaLibrary.count) items from Plex.")
                    .foregroundColor(.secondary)
                Button("Reload Library") {
                    print("[MainAppView] Reload Plex Library pressed.")
                    fetchLibrary()
                }
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
    MainAppView(userProfile: UserProfile(
        userId: "1",
        preferences: UserPreferences(
            time: "any",
            moods: [],
            genres: [],
            format: "any",
            comfortMode: false,
            surprise: false
        ),
        feedback: [],
        watchHistory: [],
        onboardingAnswers: nil,
        selectedServices: ["Plex"]
    ))
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

extension TMDBTrendingTitle {
    func toMediaItem() -> MediaItem {
        MediaItem(
            id: String(id),
            title: title,
            year: nil,
            type: type,
            genres: genres,
            directors: [],
            cast: [],
            duration: runtime ?? 0,
            viewCount: 0,
            summary: overview,
            posterURL: posterURL,
            seriesTitle: nil,
            lastRecommended: nil,
            platforms: streamingPlatforms,
            country: "us",
            isInTheaters: isInTheaters
        )
    }
} 