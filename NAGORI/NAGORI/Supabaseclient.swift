//
//  SupabaseClient.swift
//  NAGORI
//
//  Supabaseクライアントのシングルトン
//

import Foundation
import Supabase

enum SupabaseConfig {
    static let projectURL = URL(string: "https://tmtaffvbfezeiahwbrsm.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtdGFmZnZiZmV6ZWlhaHdicnNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk2MDE0NDIsImV4cCI6MjEwNTE3NzQ0Mn0.kj6eUVcOCjhvPoYfVSOx8gqo576nmFUcpGdCSDAk-V0"
}

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.projectURL,
            supabaseKey: SupabaseConfig.anonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}
