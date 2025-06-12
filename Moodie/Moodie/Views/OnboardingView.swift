import SwiftUI

struct OnboardingView: View {
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isLoggedIn = false
    
    var body: some View {
        if isLoggedIn {
            MainAppView()
        } else {
            VStack(spacing: 32) {
                Spacer()
                Text("Welcome to Moodie")
                    .font(.largeTitle)
                    .bold()
                Text("Sign in with Plex to get started.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                if isLoading {
                    ProgressView("Signing in with Plex...")
                        .padding()
                } else {
                    Button(action: startLogin) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                            Text("Sign in with Plex")
                        }
                        .font(.title2)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    // Temporary button for UI development/testing
                    Button(action: { isLoggedIn = true }) {
                        Text("Skip to App (Dev Only)")
                            .font(.subheadline)
                            .padding(8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                Spacer()
            }
            .padding()
        }
    }
    
    private func startLogin() {
        isLoading = true
        errorMessage = nil
        PlexOAuthService.shared.startLogin { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(_):
                    isLoggedIn = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct OnboardingFlowView: View {
    var onComplete: (UserProfile) -> Void
    @State private var favoriteTitles: String = ""
    @State private var favoriteGenres: Set<String> = []
    @State private var dislikedGenres: Set<String> = []
    @State private var preferredContentType: String = "any"
    @State private var preferredDuration: Int = 60
    @State private var userId: String = UUID().uuidString
    @State private var step: Int = 0
    
    let genreOptions = [
        "Action", "Comedy", "Drama", "Family", "Animation", "Thriller", "Crime", "Romance", "Biography", "Musical", "Mystery", "Historical"
    ]
    let contentTypeOptions = ["movie", "show", "any"]
    let durationOptions = [30, 60, 90, 120]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if step == 0 {
                    Text("Welcome! Let's get to know your tastes.")
                        .font(.title2)
                    TextField("Favorite movies or TV shows (comma separated)", text: $favoriteTitles)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    Button("Next") { step += 1 }
                        .padding(.top)
                } else if step == 1 {
                    Text("Pick your favorite genres")
                        .font(.title2)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(genreOptions, id: \ .self) { genre in
                                GenreChip(label: genre, isSelected: favoriteGenres.contains(genre)) {
                                    if favoriteGenres.contains(genre) {
                                        favoriteGenres.remove(genre)
                                    } else {
                                        favoriteGenres.insert(genre)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    Button("Next") { step += 1 }
                        .padding(.top)
                } else if step == 2 {
                    Text("Any genres you dislike?")
                        .font(.title2)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(genreOptions, id: \ .self) { genre in
                                GenreChip(label: genre, isSelected: dislikedGenres.contains(genre)) {
                                    if dislikedGenres.contains(genre) {
                                        dislikedGenres.remove(genre)
                                    } else {
                                        dislikedGenres.insert(genre)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    Button("Next") { step += 1 }
                        .padding(.top)
                } else if step == 3 {
                    Text("Do you prefer movies, TV shows, or both?")
                        .font(.title2)
                    Picker("Preferred Type", selection: $preferredContentType) {
                        ForEach(contentTypeOptions, id: \ .self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    Button("Next") { step += 1 }
                        .padding(.top)
                } else if step == 4 {
                    Text("What's your ideal watch time?")
                        .font(.title2)
                    Picker("Preferred Duration", selection: $preferredDuration) {
                        ForEach(durationOptions, id: \ .self) { min in
                            Text("\(min) min").tag(min)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    Button("Finish") { completeOnboarding() }
                        .padding(.top)
                }
            }
            .padding()
            .navigationTitle("Onboarding")
        }
    }
    
    private func completeOnboarding() {
        let onboarding = OnboardingAnswers(
            favoriteTitles: favoriteTitles.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            favoriteGenres: Array(favoriteGenres),
            dislikedGenres: Array(dislikedGenres),
            preferredContentType: preferredContentType,
            preferredDuration: preferredDuration
        )
        let profile = UserProfile(
            userId: userId,
            preferences: UserPreferences(
                time: "any",
                moods: [],
                genres: Array(favoriteGenres),
                format: preferredContentType,
                comfortMode: false,
                surprise: false
            ),
            feedback: [],
            watchHistory: [],
            onboardingAnswers: onboarding
        )
        onComplete(profile)
    }
}

#Preview {
    OnboardingView()
} 