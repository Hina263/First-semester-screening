//
//  UserListView.swift
//  NAGORI
//
//  Created by 寺田光希 on 2026/09/18.
//

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

enum UserListType {
    case following
    case followers
    
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
    
    // 他人のプロフィール表示用
    @State private var selectedUser: UserListItem? = nil
    
    // Supabaseから取得するユーザーリスト
    @State private var users: [UserListItem] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("読み込み中...")
                } else if users.isEmpty {
                    Text("ユーザーがいません")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach($users) { $user in
                            HStack(spacing: 12) {
                                // ユーザータップでプロフへ
                                Button {
                                    selectedUser = user
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
                                
                                // フォロー / 解除 ボタン
                                Button {
                                    Task {
                                        await toggleFollow(for: &user)
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
            // ユーザープロフィール表示モーダル
            .sheet(item: $selectedUser) { user in
                NavigationStack {
                    VStack(spacing: 16) {
                        Image(systemName: user.iconName ?? "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.pink)
                        Text(user.name)
                            .font(.title2.bold())
                        if let bio = user.bio {
                            Text(bio)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("閉じる") { selectedUser = nil }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Supabaseからユーザー一覧を取得
    private func fetchUsers() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // usersテーブルから全ユーザーを取得
            let fetchedUsers: [UserListItem] = try await SupabaseManager.shared.client
                .from("users")
                .select()
                .execute()
                .value
            
            // ログイン中の自分自身はリストから除外するなどの処理もここで可能
            if let currentUserId = SupabaseManager.shared.client.auth.currentUser?.id {
                self.users = fetchedUsers.filter { $0.id != currentUserId }
            } else {
                self.users = fetchedUsers
            }
            
        } catch {
            print("ユーザー一覧の取得エラー: \(error.localizedDescription)")
        }
    }
    
    // MARK: - フォロー・解除のSupabase連携処理
    private func toggleFollow(for user: inout UserListItem) async {
        do {
            guard let currentUserId = SupabaseManager.shared.client.auth.currentUser?.id else {
                print("エラー: ログインしていません")
                return
            }
            
            if currentUserId == user.id {
                print("エラー: 自分自身をフォローすることはできません")
                return
            }
            
            if user.isFollowing {
                try await SupabaseManager.shared.client
                    .from("follows")
                    .delete()
                    .eq("follower_id", value: currentUserId)
                    .eq("following_id", value: user.id)
                    .execute()
                
                user.isFollowing = false
                print("フォローを解除しました")
            } else {
                struct FollowInsert: Encodable {
                    let follower_id: UUID
                    let following_id: UUID
                }
                
                let newFollow = FollowInsert(follower_id: currentUserId, following_id: user.id)
                
                try await SupabaseManager.shared.client
                    .from("follows")
                    .insert(newFollow)
                    .execute()
                
                user.isFollowing = true
                print("新しくフォローしました")
            }
        } catch {
            print("フォロー処理のエラー: \(error.localizedDescription)")
        }
    }
}
