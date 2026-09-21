//
//  ProfileView.swift
//  NAGORI
//
//  M-03: プロフィール表示・編集（マイページ）
//

import SwiftUI
import Supabase

struct ProfileView: View {
    @EnvironmentObject var auth: AuthManager

    // sheetの状態を1つにまとめる（別々のBool/Optionalを複数持つと
    // タイミングによって二重に開いてしまうことがあるため）
    private enum ActiveSheet: Identifiable {
        case editProfile
        case userList(UserListType)
        case postDetail(Post)

        var id: String {
            switch self {
            case .editProfile:
                return "editProfile"
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

    // フォロー中・フォロワーの人数
    @State private var followingCount = 0
    @State private var followersCount = 0

    // 自分の投稿一覧
    @State private var myPosts: [Post] = []
    @State private var isLoadingMyPosts = false

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

                Text(auth.currentProfile?.userName ?? "名前未設定")
                    .font(.title2.bold())

                Button("プロフィールを編集") {
                    activeSheet = .editProfile
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 48)
                .buttonStyle(.plain)

                // フォロー中・フォロワーへの導線（タップでUserListViewを開く）
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
        .navigationTitle("マイページ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("ログアウト", role: .destructive) {
                    Task { await auth.signOut() }
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .editProfile:
                ProfileEditView()
            case .userList(let type):
                UserListView(listType: type)
            case .postDetail(let post):
                PostDetailView(
                    post: post,
                    onDeleted: { deletedPost in
                        myPosts.removeAll { $0.id == deletedPost.id }
                    },
                    onUpdated: { updatedPost in
                        if let idx = myPosts.firstIndex(where: { $0.id == updatedPost.id }) {
                            myPosts[idx] = updatedPost
                        }
                    }
                )
                .presentationDetents([.large])
            }
        }
        .task {
            async let postsTask: Void = loadMyPosts()
            async let countsTask: Void = loadFollowCounts()
            _ = await (postsTask, countsTask)
        }
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

    // MARK: - 自分の投稿（M-03）

    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("自分の投稿")
                    .font(.subheadline.bold())
                Spacer()
                if !myPosts.isEmpty {
                    Text("\(myPosts.count)件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            if isLoadingMyPosts {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else if myPosts.isEmpty {
                Text("まだ投稿がありません")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 2) {
                    ForEach(myPosts) { post in
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
            // セル幅と同じ高さに固定して正方形にする（これが無いと読み込んだ画像が際限なく大きくなる）
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

    private func loadMyPosts() async {
        guard let userId = auth.currentProfile?.id else { return }
        isLoadingMyPosts = true
        defer { isLoadingMyPosts = false }
        do {
            myPosts = try await PostService.fetchPosts(authorId: userId)
        } catch {
            print("自分の投稿の取得に失敗しました: \(error.localizedDescription)")
        }
    }

    // MARK: - フォロー数・フォロワー数の取得

    private struct FollowIdRow: Decodable {
        let follower_id: UUID
        let following_id: UUID
    }

    private func loadFollowCounts() async {
        guard let userId = auth.currentProfile?.id else { return }
        do {
            let followingRows: [FollowIdRow] = try await SupabaseManager.shared.client
                .from("follows")
                .select()
                .eq("follower_id", value: userId)
                .execute()
                .value
            followingCount = followingRows.count

            let followerRows: [FollowIdRow] = try await SupabaseManager.shared.client
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

    // MARK: - アイコン表示

    @ViewBuilder
    private var avatar: some View {
        if let urlString = auth.currentProfile?.iconUrl, let url = URL(string: urlString) {
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
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AuthManager.shared)
    }
}
