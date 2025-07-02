//
//  MoodieApp.swift
//  Moodie
//
//  Created by Chris Ritchhart on 6/11/25.
//

import SwiftUI

@main
struct MoodieApp: App {
    @AppStorage("isOnboarded") private var isOnboarded: Bool = false
    @State private var userProfile: UserProfile? = UserProfileStore.shared.load()

    var body: some Scene {
        WindowGroup {
            if isOnboarded, let profile = userProfile {
                MainAppView(userProfile: profile)
            } else {
                OnboardingFlowView { profile in
                    UserProfileStore.shared.save(profile)
                    userProfile = profile
                    isOnboarded = true
                }
            }
        }
    }
}
