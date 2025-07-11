import SwiftUI

struct OnboardingFlowView: View {
    let SERVICE_SELECTION_STEP = 0
    var onComplete: (UserProfile) -> Void
    var onlyStreaming: Bool = false
    var onlyPreferences: Bool = false
    @State private var favoriteTitles: String = ""
    @State private var favoriteGenres: Set<String> = []
    @State private var dislikedGenres: Set<String> = []
    @State private var preferredContentType: String = "any"
    @State private var preferredDuration: Int = 60
    @State private var userId: String = UUID().uuidString
    @State private var step: Int = 0
    @State private var selectedServices: Set<String> = []
    @State private var showPlexSignIn: Bool = false
    let allServices = ["Netflix", "HBO", "Disney+", "Paramount+", "Apple TV+", "Plex"]
    @State private var userProfile: UserProfile? = nil
    @State private var hasCompletedPlexAuth = false

    let genreOptions = [
        "Action", "Comedy", "Drama", "Family", "Animation", "Thriller", "Crime", "Romance", "Biography", "Musical", "Mystery", "Historical"
    ]
    let contentTypeOptions = ["movie", "show"]
    let durationOptions = [30, 60, 90, 120]

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Swipe down to skip onboarding")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                if onlyPreferences {
                    PreferencesSteps
                } else if onlyStreaming {
                    StreamingStep
                } else if step == SERVICE_SELECTION_STEP {
                    Text("Which streaming services do you subscribe to?")
                        .font(.title2)
                    VStack(spacing: 12) {
                        ForEach(allServices, id: \.self) { service in
                            Button(action: {
                                if selectedServices.contains(service) {
                                    selectedServices.remove(service)
                                } else {
                                    selectedServices.insert(service)
                                }
                            }) {
                                HStack {
                                    Image(systemName: selectedServices.contains(service) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(.accentColor)
                                    Text(service)
                                        .font(.headline)
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    Button("Next") {
                        print("[DEBUG] Next button tapped. selectedServices: \(selectedServices)")
                        if selectedServices.contains("Plex") {
                            showPlexSignIn = true
                        } else {
                            if onlyStreaming {
                                completeStreamingOnly()
                            } else {
                                step += 1
                            }
                        }
                    }
                    .padding(.top)
                    .disabled(selectedServices.isEmpty)
                } else if step == 1 {
                    PreferencesSteps
                } else if step == 2 {
                    Text("Pick your favorite genres")
                        .font(.title2)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(genreOptions, id: \.self) { genre in
                                GenreChip(label: genre, isSelected: favoriteGenres.contains(genre), action: {
                                    if favoriteGenres.contains(genre) {
                                        favoriteGenres.remove(genre)
                                    } else {
                                        favoriteGenres.insert(genre)
                                    }
                                })
                            }
                        }
                        .padding(.horizontal)
                    }
                    Button("Next") { step += 1 }
                        .padding(.top)
                } else if step == 3 {
                    Text("Any genres you dislike?")
                        .font(.title2)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(genreOptions, id: \.self) { genre in
                                GenreChip(label: genre, isSelected: dislikedGenres.contains(genre), action: {
                                    if dislikedGenres.contains(genre) {
                                        dislikedGenres.remove(genre)
                                    } else {
                                        dislikedGenres.insert(genre)
                                    }
                                })
                            }
                        }
                        .padding(.horizontal)
                    }
                    Button("Next") { step += 1 }
                        .padding(.top)
                } else if step == 4 {
                    Text("Do you prefer movies or TV shows?")
                        .font(.title2)
                    Picker("Preferred Type", selection: $preferredContentType) {
                        ForEach(contentTypeOptions, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    Button("Next") { step += 1 }
                        .padding(.top)
                } else if step == 5 {
                    Text("What's your ideal watch time?")
                        .font(.title2)
                    Picker("Preferred Duration", selection: $preferredDuration) {
                        ForEach(durationOptions, id: \.self) { min in
                            Text("\(min) min").tag(min)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    Button("Finish") {
                        print("[DEBUG] Finish button tapped. selectedServices: \(selectedServices)")
                        completePreferencesOnly()
                    }
                    .padding(.top)
                    .disabled(selectedServices.isEmpty || (selectedServices.contains("Plex") && !hasCompletedPlexAuth))
                }
            }
            .padding()
            .navigationTitle("Onboarding")
            .sheet(isPresented: $showPlexSignIn) {
                PlexSignInView(onComplete: { plexProfile in
                    selectedServices.insert("Plex")
                    hasCompletedPlexAuth = true
                    print("[DEBUG] Plex sign-in complete. selectedServices: \(selectedServices)")
                })
            }
        }
    }

    @ViewBuilder
    var PreferencesSteps: some View {
        if step == 1 || onlyPreferences {
            Text("Welcome! Let's get to know your tastes.")
                .font(.title2)
            TextField("Favorite movies or TV shows (comma separated)", text: $favoriteTitles)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            Button("Next") { step = 2 }
                .padding(.top)
        } else if step == 2 {
            Text("Pick your favorite genres")
                .font(.title2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(genreOptions, id: \.self) { genre in
                        GenreChip(label: genre, isSelected: favoriteGenres.contains(genre), action: {
                            if favoriteGenres.contains(genre) {
                                favoriteGenres.remove(genre)
                            } else {
                                favoriteGenres.insert(genre)
                            }
                        })
                    }
                }
                .padding(.horizontal)
            }
            Button("Next") { step = 3 }
                .padding(.top)
        } else if step == 3 {
            Text("Any genres you dislike?")
                .font(.title2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(genreOptions, id: \.self) { genre in
                        GenreChip(label: genre, isSelected: dislikedGenres.contains(genre), action: {
                            if dislikedGenres.contains(genre) {
                                dislikedGenres.remove(genre)
                            } else {
                                dislikedGenres.insert(genre)
                            }
                        })
                    }
                }
                .padding(.horizontal)
            }
            Button("Next") { step = 4 }
                .padding(.top)
        } else if step == 4 {
            Text("Do you prefer movies or TV shows?")
                .font(.title2)
            Picker("Preferred Type", selection: $preferredContentType) {
                ForEach(contentTypeOptions, id: \.self) { type in
                    Text(type.capitalized).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            Button("Next") { step = 5 }
                .padding(.top)
        } else if step == 5 {
            Text("What's your ideal watch time?")
                .font(.title2)
            Picker("Preferred Duration", selection: $preferredDuration) {
                ForEach(durationOptions, id: \.self) { min in
                    Text("\(min) min").tag(min)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            Button("Finish") { completePreferencesOnly() }
                .padding(.top)
        }
    }

    @ViewBuilder
    var StreamingStep: some View {
        Text("Which streaming services do you subscribe to?")
            .font(.title2)
        VStack(spacing: 12) {
            ForEach(allServices, id: \.self) { service in
                Button(action: {
                    if selectedServices.contains(service) {
                        selectedServices.remove(service)
                    } else {
                        selectedServices.insert(service)
                    }
                }) {
                    HStack {
                        Image(systemName: selectedServices.contains(service) ? "checkmark.square.fill" : "square")
                            .foregroundColor(.accentColor)
                        Text(service)
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        Button("Finish") { completeStreamingOnly() }
            .padding(.top)
            .disabled(selectedServices.isEmpty)
    }

    private func completeStreamingOnly() {
        print("[Onboarding] completeStreamingOnly selectedServices: \(selectedServices)")
        let profile = UserProfile(
            userId: userId,
            preferences: UserPreferences(time: "any", moods: [], genres: [], format: "any", comfortMode: false, surprise: false),
            feedback: [],
            watchHistory: [],
            onboardingAnswers: nil,
            selectedServices: Array(selectedServices)
        )
        print("[Onboarding] Saving profile: \(profile.selectedServices)")
        UserProfileStore.shared.save(profile)
        onComplete(profile)
    }

    private func completePreferencesOnly() {
        print("[Onboarding] completePreferencesOnly selectedServices: \(selectedServices)")
        var profile: UserProfile = {
            do {
                return UserProfileStore.shared.load()
            } catch {
                return UserProfile(
                    userId: UUID().uuidString,
                    preferences: UserPreferences(time: "any", moods: [], genres: [], format: "any", comfortMode: false, surprise: false),
                    feedback: [],
                    watchHistory: [],
                    onboardingAnswers: nil,
                    selectedServices: []
                )
            }
        }()
        profile.selectedServices = Array(selectedServices)
        print("[Onboarding] Saving profile: \(profile.selectedServices)")
        UserProfileStore.shared.save(profile)
        onComplete(profile)
    }
}

struct PlexSignInView: View {
    var onComplete: (UserProfile) -> Void
    @State private var isLoading = false
    @State private var error: String?
    @AppStorage("isOnboarded") private var isOnboarded: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Sign in to Plex")
                .font(.title2)
            if isLoading {
                ProgressView("Connecting to Plex...")
            } else {
                Button("Connect to Plex") {
                    isLoading = true
                    error = nil
                    PlexOAuthService.shared.startLogin { result in
                        DispatchQueue.main.async {
                            isLoading = false
                            switch result {
                            case .success(_):
                                // Build a UserProfile and call onComplete
                                var profile = UserProfile(
                                    userId: UUID().uuidString,
                                    preferences: UserPreferences(time: "any", moods: [], genres: [], format: "any", comfortMode: false, surprise: false),
                                    feedback: [],
                                    watchHistory: [],
                                    onboardingAnswers: nil,
                                    selectedServices: ["Plex"]
                                )
                                // Try to merge with any existing onboarding data
                                let existingProfile = try? UserProfileStore.shared.load()
                                if let existingProfile = existingProfile {
                                    profile.selectedServices = Array(Set(existingProfile.selectedServices).union(["Plex"]))
                                    profile.preferences = existingProfile.preferences
                                    profile.onboardingAnswers = existingProfile.onboardingAnswers
                                    profile.feedback = existingProfile.feedback
                                    profile.watchHistory = existingProfile.watchHistory
                                }
                                print("[PlexSignInView] Saving profile: \(profile.selectedServices)")
                                UserProfileStore.shared.save(profile)
                                isOnboarded = true
                                onComplete(profile)
                            case .failure(let err):
                                error = err.localizedDescription
                            }
                        }
                    }
                }
            }
            if let error = error {
                Text(error)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
}

struct OnboardingFlowView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingFlowView { _ in }
    }
}
