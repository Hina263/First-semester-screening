//
//  UserProfileView.swift
//  NAGORI
//
//  他人のプロフィール画面。マイページ(ProfileView)と同じ内容
//  （アイコン・名前・フォロー中/フォロワー・投稿一覧）を表示し、
//  編集/ログアウトの代わりにフォローボタンを出す。
//

import SwiftUI
import Supabase

struct UserProfileView: View {
    let userId: UUID

    @EnvironmentObject var auth: AuthManager

    @State private var profile: UserProfile?
    @State private var isFollowing = false
    @State private var isTogglingFollow = false

    // フォロー中・フォロワーの人数
    @State private var followingCount = 0
    @State private var followersCount = 0

    @State private var posts: [Post] = []
    @State private var isLoadingPosts = false

    @State private var errorMessage: String?

    // sheetの状態をまとめる（ProfileView/MainMapViewと同じ方針）
    private enum ActiveSheet: Identifiable {
        case userList(UserListType)
        case postDetail(Post)

        var id: String {
            switch self {
            case .userList(let type):
                switch type {
                case .following: return "userList-following"
                case .followers: return "userList-followers"
                }
            case .postDetail(let post):
                return "postDetail-\(post.id.uuidString)"
            }
        }
    }
    @State private var activeSheet: ActiveSheet?

    private let gridColumns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                avatar
                    .padding(.top, 24)

                Text(profile?.userName ?? "読み込み中...")
                    .font(.title2.bold())

                followButton

                HStack(spacing: 0) {
                    statButton(count: followingCount, title: "フォロー", type: .following)
                    Divider().frame(height: 28)
                    statButton(count: followersCount, title: "フォロワー", type: .followers)
                }
                .padding(.top, 4)

                postsSection
                    .padding(.top, 12)
            }
            .padding(.bottom, 24)
        }
        .navigationTitle(profile.map { "\($0.userName)のプロフィール" } ?? "プロフィール")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .userList(let type):
                UserListView(listType: type, subjectUserId: userId)
            case .postDetail(let post):
                PostDetailView(
                    post: post,
                    onDeleted: { deletedPost in
                        posts.removeAll { $0.id == deletedPost.id }
                    },
                    onUpdated: { updatedPost in
                        if let idx = posts.firstIndex(where: { $0.id == updatedPost.id }) {
                            posts[idx] = updatedPost
                        }
                    },
                    onBlocked: { blockedUserId in
                        if blockedUserId == userId {
                            posts.removeAll()
                        }
                    }
                )
                .presentationDetents([.large])
            }
        }
        .alert("エラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            async let profileTask: Void = loadProfile()
            async let followTask: Void = loadFollowStatus()
            async let postsTask: Void = loadPosts()
            async let countsTask: Void = loadFollowCounts()
            _ = await (profileTask, followTask, postsTask, countsTask)
        }
    }

    // MARK: - アイコン

    @ViewBuilder
    private var avatar: some View {
        if let urlString = profile?.iconUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholderAvatar
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
        } else {
            placeholderAvatar
                .frame(width: 120, height: 120)
        }
    }

    private var placeholderAvatar: some View {
        ZStack {
            Circle().fill(Color.pink)
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundStyle(.white)
        }
    }

    // MARK: - フォローボタン（編集/ログアウトの代わりにここに出す）

    private var followButton: some View {
        Button {
            Task { await toggleFollow() }
        } label: {
            Text(isFollowing ? "フォロー中" : "フォロー")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isFollowing ? Color.primary : Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isFollowing ? Color(.systemGray5) : Color.pink)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 48)
        .disabled(isTogglingFollow)
    }

    private func statButton(count: Int, title: String, type: UserListType) -> some View {
        Button {
            activeSheet = .userList(type)
        } label: {
            VStack(spacing: 2) {
                Text("\(count)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 投稿一覧（マイページの「自分の投稿」と同じグリッド）

    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("投稿")
                    .font(.subheadline.bold())
                Spacer()
                if !posts.isEmpty {
                    Text("\(posts.count)件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            if isLoadingPosts {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else if posts.isEmpty {
                Text("まだ投稿がありません")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 2) {
                    ForEach(posts) { post in
                        Button {
                            activeSheet = .postDetail(post)
                        } label: {
                            postThumbnail(post)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func postThumbnail(_ post: Post) -> some View {
        GeometryReader { geo in
            Group {
                if let url = post.imageUrl.flatMap(URL.init(string:)) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            thumbnailPlaceholder
                        }
                    }
                } else {
                    thumbnailPlaceholder
                }
            }
            .frame(width: geo.size.width, height: geo.size.width)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                if !post.locationName.isEmpty {
                    Text(post.locationName)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.35))
                        .lineLimit(1)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            Color(.systemGray5)
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - データ取得

    private func loadProfile() async {
        do {
            profile = try await PostService.fetchAuthor(id: userId)
        } catch {
            errorMessage = "プロフィールを取得できませんでした: \(error.localizedDescription)"
        }
    }

    private func loadPosts() async {
        isLoadingPosts = true
        defer { isLoadingPosts = false }
        do {
            posts = try await PostService.fetchPosts(authorId: userId)
        } catch {
            print("投稿一覧の取得に失敗しました: \(error.localizedDescription)")
        }
    }

    private func loadFollowStatus() async {
        do {
            let myId = try await SupabaseManager.shared.client.auth.session.user.id
            guard myId != userId else { return } // 自分自身は対象外
            let rows: [FollowCheckRow] = try await SupabaseManager.shared.client
                .from("follows")
                .select()
                .eq("follower_id", value: myId)
                .eq("following_id", value: userId)
                .execute()
                .value
            isFollowing = !rows.isEmpty
        } catch {
            // フォロー状態が取れなくても致命的ではないので静かに失敗させる（ボタンは未フォロー扱いのまま）
        }
    }

    private func loadFollowCounts() async {
        do {
            let followingRows: [FollowCheckRow] = try await SupabaseManager.shared.client
                .from("follows")
                .select()
                .eq("follower_id", value: userId)
                .execute()
                .value
            followingCount = followingRows.count

            let followerRows: [FollowCheckRow] = try await SupabaseManager.shared.client
                .from("follows")
                .select()
                .eq("following_id", value: userId)
                .execute()
                .value
            followersCount = followerRows.count
        } catch {
            print("フォロー数の取得に失敗しました: \(error.localizedDescription)")
        }
    }

    private func toggleFollow() async {
        isTogglingFollow = true
        defer { isTogglingFollow = false }
        do {
            let myId = try await SupabaseManager.shared.client.auth.session.user.id
            guard myId != userId else { return }

            if isFollowing {
                try await SupabaseManager.shared.client
                    .from("follows")
                    .delete()
                    .eq("follower_id", value: myId)
                    .eq("following_id", value: userId)
                    .execute()
                isFollowing = false
                followersCount = max(0, followersCount - 1)
            } else {
                struct FollowInsert: Encodable {
                    let follower_id: UUID
                    let following_id: UUID
                }
                try await SupabaseManager.shared.client
                    .from("follows")
                    .insert(FollowInsert(follower_id: myId, following_id: userId))
                    .execute()
                isFollowing = true
                followersCount += 1
            }
        } catch {
            errorMessage = "フォロー処理に失敗しました: \(error.localizedDescription)"
        }
    }
}

private struct FollowCheckRow: Decodable {
    let follower_id: UUID
    let following_id: UUID
}

#Preview {
    NavigationStack {
        UserProfileView(userId: UUID())
            .environmentObject(AuthManager.shared)
    }
}
