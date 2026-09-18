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

    

    // ★ 追加：通報画面を表示するためのフラグ

    @State private var showReportView = false



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



            // ★ 追加：通報機能をテストするためのボタン

            Button("【テスト】通報画面を開く") {

                showReportView = true

            }

            .buttonStyle(.borderedProminent)



            Divider()



            Button("ログアウト", role: .destructive) {

                Task { await auth.signOut() }

            }

        }

        .padding()

        // ★ 追加：ボタンが押されたときに ReportView をポップアップ表示する

        .sheet(isPresented: $showReportView) {

            ReportView(targetPostId: "633bd377-db56-4d24-bf21-62ce4e17d8b1", targetUserName: "テストユーザー")

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
