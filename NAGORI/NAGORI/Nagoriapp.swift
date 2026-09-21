//
//  NAGORIApp.swift
//  NAGORI
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
        case .signedOut:
            LoginView()
        case .signedIn(let profile):
            if profile == nil {
                // まだusersに行がない=初回。専用の初期設定画面を表示
                ProfileSetupView()
            } else {
                MainMapView()
            }
        }
    }
}
