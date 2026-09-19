//
//  ContentView.swift
//  NAGORI
//
//  Created by 長野日向人 on 2026/09/17.
//

import SwiftUI
import Supabase

struct ContentView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var connectionStatus: String = "未確認"
    @State private var isChecking = false
    @State private var isEditingProfile = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")

                Divider()

                Text("Supabase接続: \(connectionStatus)")
                    .font(.caption)

                Button(isChecking ? "確認中..." : "接続テスト") {
                    Task { await checkConnection() }
                }
                .disabled(isChecking)

                Divider()

                NavigationLink {
                    ProfileView()
                } label: {
                    Text("マイページ")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button("プロフィールを編集") {
                    isEditingProfile = true
                }
                .buttonStyle(.bordered)

                Button("ログアウト", role: .destructive) {
                    Task { await auth.signOut() }
                }
            }
            .padding()
            .sheet(isPresented: $isEditingProfile) {
                ProfileEditView()
            }
        }
    }

    private func checkConnection() async {
        isChecking = true
        defer { isChecking = false }
        do {
            // 存在確認用の軽いクエリ。テーブルが未作成でも
            // エラーの内容で疎通自体はできているか判断できる
            _ = try await SupabaseManager.shared.client
                .from("_dummy_connection_check")
                .select()
                .limit(1)
                .execute()
            connectionStatus = "成功"
        } catch {
            // テーブルが存在しないエラーでも、Supabaseサーバーへの
            // 到達自体はできていれば実質OK
            connectionStatus = "応答あり（詳細: \(error.localizedDescription)）"
        }
    }
}

#Preview {
    ContentView()
}
