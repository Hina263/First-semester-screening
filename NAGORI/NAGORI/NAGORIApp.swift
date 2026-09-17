//
//  Created by 長野日向人 on 2026/09/17.
//

import SwiftUI

@main
struct NAGORIApp: App {
    @StateObject private var auth = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .task { await auth.bootstrap() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        switch auth.state {
        case .loading:
            ProgressView()
        case .signedOut, .failed:
            LoginView()
        case .needsProfileSetup:
            ProfileSetupView()
        case .signedIn:
            ContentView() // TODO: M-07のマップ画面に置き換える
        }
    }
}
