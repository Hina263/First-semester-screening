//
//  ReportView.swift
//  NAGORI
//
//  Created by 寺田光希 on 2026/09/18.
//
import SwiftUI
import Supabase
import Auth

struct ReportView: View {
    @Environment(\.dismiss) private var dismiss

    let targetPostId: String
    /// ブロック機能に使う投稿者のユーザーID（渡されなければブロックトグルは出さない）
    var targetUserId: UUID? = nil
    let targetUserName: String
    /// ブロックに成功した時に呼ばれる（マップ側でその場から投稿を取り除くのに使う）
    var onBlocked: ((UUID) -> Void)? = nil

    @State private var selectedReason: String = "不適切な画像・コンテンツ"
    @State private var detailText: String = ""
    @State private var shouldBlockUser: Bool = false
    @State private var isSubmitted: Bool = false
    @State private var isSending: Bool = false
    @State private var errorMessage: String?
    
    private let reportReasons = [
        "不適切な画像・コンテンツ",
        "スパム・迷惑行為・宣伝",
        "個人情報の開示・プライバシー侵害",
        "ハラスメント・誹謗中傷",
        "その他"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(targetUserName) さんの投稿に通報を行います。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Picker("通報の理由", selection: $selectedReason) {
                        ForEach(reportReasons, id: \.self) { reason in
                            Text(reason).tag(reason)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("理由を選択")
                }
                
                Section {
                    TextEditor(text: $detailText)
                        .frame(height: 100)
                } header: {
                    Text("詳細（任意）")
                }
                
                if targetUserId != nil {
                    Section {
                        Toggle(isOn: $shouldBlockUser) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(targetUserName) さんをブロックする")
                                    .font(.body)
                                Text("今後このユーザーの投稿が非表示になります。")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("投稿の通報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("送信") {
                        Task { await sendReport() }
                    }
                    .bold()
                    .disabled(isSending)
                }
            }
            .disabled(isSending)
            .alert("通報を送信しました", isPresented: $isSubmitted) {
                Button("OK") { dismiss() }
            } message: {
                Text("ご協力ありがとうございます。運営チームで確認の上、適切に対応いたします。")
            }
            .alert("エラー", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @MainActor
    private func sendReport() async {
        isSending = true
        defer { isSending = false }
        do {
            // .currentUser（同期キャッシュ）はアカウント切り替え直後に更新が追いつかず
            // nilを返すことがあるため、session経由で確実に今ログイン中のUUIDを取る
            let currentUserUUID = try await SupabaseManager.shared.client.auth.session.user.id
            let combinedReason = detailText.isEmpty ? selectedReason : "\(selectedReason): \(detailText)"

            // 送信用のデータ構造体（Supabaseの型定義に一致させる）
            struct ReportPayload: Encodable {
                let target_post_id: String
                let reporter_id: UUID
                let reason: String
            }

            let payload = ReportPayload(
                target_post_id: targetPostId,
                reporter_id: currentUserUUID,
                reason: combinedReason
            )

            try await SupabaseManager.shared.client
                .from("reports")
                .insert(payload)
                .execute()

            // ブロックトグルがONなら、続けてblocksテーブルにも書き込む
            if shouldBlockUser, let targetUserId {
                struct BlockPayload: Encodable {
                    let blocker_id: UUID
                    let blocked_id: UUID
                }
                try await SupabaseManager.shared.client
                    .from("blocks")
                    .insert(BlockPayload(blocker_id: currentUserUUID, blocked_id: targetUserId))
                    .execute()
                onBlocked?(targetUserId)
            }

            isSubmitted = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ReportView(targetPostId: "123", targetUserName: "さくら太郎")
}
