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
    
    // 通報画面を表示するためのフラグと動的取得するID
    @State private var showReportView = false
    @State private var targetPostId: String = ""
    @State private var targetUserName: String = "テストユーザー"
    @State private var isLoadingPost = false
    
    // フォロー一覧画面を表示するためのフラグ
    @State private var showUserList = false

    var body: some View {
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

            // 通報機能をテストするためのボタン（タップ時にSupabaseから実在の投稿IDを取得）
            Button(isLoadingPost ? "読み込み中..." : "【テスト】通報画面を開く") {
                Task {
                    await prepareAndOpenReportView()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoadingPost)

            Divider()

            // フォロー一覧機能をテストするためのボタン
            Button("【テスト】フォロー一覧を開く") {
                showUserList = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)

            Divider()

            Button("ログアウト", role: .destructive) {
                Task { await auth.signOut() }
            }
        }
        .padding()
        // 通報画面をポップアップ表示
        .sheet(isPresented: $showReportView) {
            ReportView(targetPostId: targetPostId, targetUserName: targetUserName)
        }
        // フォロー一覧画面をポップアップ表示
        .sheet(isPresented: $showUserList) {
            UserListView(listType: .following)
        }
    }

    // MARK: - 通報テスト用の投稿IDを動的に取得する処理
    private func prepareAndOpenReportView() async {
        isLoadingPost = true
        defer { isLoadingPost = false }
        
        do {
            struct PostItem: Codable {
                let id: UUID
            }
            
            // Supabaseの posts テーブルから最新の投稿を1件取得する
            let posts: [PostItem] = try await SupabaseManager.shared.client
                .from("posts")
                .select("id")
                .limit(1)
                .execute()
                .value
            
            if let firstPost = posts.first {
                self.targetPostId = firstPost.id.uuidString
                self.showReportView = true
            } else {
                print("エラー: 通報対象となる投稿がデータベースにありません")
            }
        } catch {
            print("投稿IDの取得エラー: \(error.localizedDescription)")
        }
    }

    private func checkConnection() async {
        isChecking = true
        defer { isChecking = false }
        do {
            _ = try await SupabaseManager.shared.client
                .from("reports")
                .select()
                .limit(1)
                .execute()
            connectionStatus = "成功"
        } catch {
            connectionStatus = "応答あり（詳細: \(error.localizedDescription)）"
        }
    }
}

#Preview {
    ContentView()
}
