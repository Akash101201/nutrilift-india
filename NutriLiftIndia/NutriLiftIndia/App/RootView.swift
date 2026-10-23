import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var seedError: String?

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        Group {
            if let profile, profile.onboardingComplete {
                MainTabView()
            } else {
                OnboardingFlowView()
            }
        }
        .task {
            do {
                try SeedLoader.seedIfNeeded(context: modelContext)
            } catch {
                seedError = error.localizedDescription
            }
        }
        .alert("Seed data", isPresented: Binding(
            get: { seedError != nil },
            set: { if !$0 { seedError = nil } }
        )) {
            Button("OK", role: .cancel) { seedError = nil }
        } message: {
            Text(seedError ?? "")
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
            FoodDiaryView()
                .tabItem { Label("Food", systemImage: "fork.knife") }
            WorkoutsHomeView()
                .tabItem { Label("Workouts", systemImage: "dumbbell") }
            ProgressHomeView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            CoachHomeView()
                .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
