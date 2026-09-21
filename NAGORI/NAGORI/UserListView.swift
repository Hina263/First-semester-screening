//
//  UserListView.swift
//  NAGORI
//
//  Created by 寺田光希 on 2026/09/18.
//
//  フォロー中・フォロワーの一覧。followsテーブルを実際に参照して絞り込む。

import Foundation
import SwiftUI
import Supabase

// ユーザーデータモデルの定義
struct UserListItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let iconName: String?
    let bio: String?
    var isFollowing: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case name = "user_name" // Supabaseのカラム名に合わせてマッピング
        case iconName = "icon_url"
        case bio
    }
}

/// followsテーブルの1行分（follower_idがfollowing_idをフォローしている、という関係）
private struct FollowRow: Decodable {
    let follower_id: UUID
    let following_id: UUID
}

enum UserListType: Identifiable {
    case following
    case followers

    var id: Self { self }

    var title: String {
        switch self {
        case .following: return "フォロー中"
        case .followers: return "フォロワー"
        }
    }
}

struct UserListView: View {
    @Environment(\.dismiss) private var dismiss
    let listType: UserListType
    /// 誰のフォロー中/フォロワー一覧かを指定する。nilなら今ログイン中の自分自身
    let subjectUserId: UUID?

    init(listType: UserListType, subjectUserId: UUID? = nil) {
        self.listType = listType
        self.subjectUserId = subjectUserId
    }

    // Supabaseから取得するユーザーリスト
    @State private var users: [UserListItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("読み込み中...")
                } else if users.isEmpty {
                    Text(listType == .following ? "まだ誰もフォローしていません" : "まだフォロワーがいません")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach($users) { $user in
                            HStack(spacing: 12) {
                                // ユーザータップでプロフへ
                                NavigationLink {
                                    UserProfileView(userId: user.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: user.iconName ?? "person.crop.circle.fill")
                                            .resizable()
                                            .frame(width: 44, height: 44)
                                            .foregroundColor(.pink)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(user.name)
                                                .font(.headline)
                                                .foregroundColor(.primary)

                                            if let bio = user.bio, !bio.isEmpty {
                                                Text(bio)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                // フォロー / 解除 ボタン（フォロワー一覧でもフォロー返しができる）
                                Button {
                                    Task {
                                        await toggleFollow(for: $user)
                                    }
                                } label: {
                                    Text(user.isFollowing ? "フォロー中" : "フォロー")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(user.isFollowing ? Color(.systemGray5) : Color.pink)
                                        .foregroundColor(user.isFollowing ? .primary : .white)
                                        .cornerRadius(16)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(listType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                await fetchUsers()
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

    // MARK: - Supabaseからユーザー一覧を取得（followsテーブルで実際に絞り込む）

    private func fetchUsers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // .currentUser（同期キャッシュ）はアカウント切り替え直後などに古い値を返すことがあるため
            // session経由で確実に今ログイン中のUUIDを取る
            let currentUserId = try await SupabaseManager.shared.client.auth.session.user.id
            // このリストが「誰の」フォロー中/フォロワーかを表すID（指定が無ければ自分自身）
            let targetUserId = subjectUserId ?? currentUserId

            // 自分がフォローしている全員のIDは、フォロー中/フォロワーどちらの画面でも
            // 「フォローボタンの状態」を正しく出すために必要（他人の一覧を見ている時も同じ）
            let myFollowingRows: [FollowRow] = try await SupabaseManager.shared.client
                .from("follows")
                .select()
                .eq("follower_id", value: currentUserId)
                .execute()
                .value
            let myFollowingIds = Set(myFollowingRows.map { $0.following_id })

            // このリストに出すべき対象ユーザーIDを絞り込む
            let targetUserIds: [UUID]
            switch listType {
            case .following:
                if targetUserId == currentUserId {
                    targetUserIds = Array(myFollowingIds)
                } else {
                    let rows: [FollowRow] = try await SupabaseManager.shared.client
                        .from("follows")
                        .select()
                        .eq("follower_id", value: targetUserId)
                        .execute()
                        .value
                    targetUserIds = rows.map { $0.following_id }
                }
            case .followers:
                let followerRows: [FollowRow] = try await SupabaseManager.shared.client
                    .from("follows")
                    .select()
                    .eq("following_id", value: targetUserId)
                    .execute()
                    .value
                targetUserIds = followerRows.map { $0.follower_id }
            }

            guard !targetUserIds.isEmpty else {
                self.users = []
                return
            }

            var fetchedUsers: [UserListItem] = try await SupabaseManager.shared.client
                .from("users")
                .select()
                .in("id", values: targetUserIds)
                .execute()
                .value

            // 自分が既にフォロー済みかどうかを各ユーザーに反映
            // （フォロワー一覧では、相手をフォローし返しているかどうかがここで決まる）
            for index in fetchedUsers.indices {
                fetchedUsers[index].isFollowing = myFollowingIds.contains(fetchedUsers[index].id)
            }

            self.users = fetchedUsers.sorted { $0.name < $1.name }

        } catch {
            errorMessage = "ユーザー一覧を取得できませんでした: \(error.localizedDescription)"
        }
    }

    // MARK: - フォロー・解除のSupabase連携処理

    private func toggleFollow(for user: Binding<UserListItem>) async {
        do {
            let currentUserId = try await SupabaseManager.shared.client.auth.session.user.id

            if currentUserId == user.wrappedValue.id {
                errorMessage = "自分自身をフォローすることはできません"
                return
            }

            if user.wrappedValue.isFollowing {
                try await SupabaseManager.shared.client
                    .from("follows")
                    .delete()
                    .eq("follower_id", value: currentUserId)
                    .eq("following_id", value: user.wrappedValue.id)
                    .execute()

                user.wrappedValue.isFollowing = false
            } else {
                struct FollowInsert: Encodable {
                    let follower_id: UUID
                    let following_id: UUID
                }

                let newFollow = FollowInsert(follower_id: currentUserId, following_id: user.wrappedValue.id)

                try await SupabaseManager.shared.client
                    .from("follows")
                    .insert(newFollow)
                    .execute()

                user.wrappedValue.isFollowing = true
            }
        } catch {
            errorMessage = "フォロー処理に失敗しました: \(error.localizedDescription)"
        }
    }
}
