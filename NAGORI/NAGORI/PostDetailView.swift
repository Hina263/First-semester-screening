//
//  PostDetailView.swift
//  NAGORI
//
//  M-10 投稿詳細表示　担当: まなと
//  写真・投稿者・コメント・投稿日時・場所を表示する。投稿者タップでプロフィールへ。
//

import SwiftUI
import CoreLocation

struct PostDetailView: View {

    let post: Post

    @Environment(\.dismiss) private var dismiss
    @State private var author: UserProfile?
    @State private var isShowingReport = false

    /// 取得できるまでは投稿に入っている名前を出しておく
    private var authorName: String {
        author?.userName ?? post.authorName
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    authorHeader
                    photo
                    placeInfo
                    if !post.comment.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("投稿コメント")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(post.comment)
                                .font(.body)
                                .lineSpacing(4)
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                guard let authorId = post.authorId else { return }
                author = try? await PostService.fetchAuthor(id: authorId)
            }
            .sheet(isPresented: $isShowingReport) {
                // M-12（てるる担当）の通報画面へ投稿IDを渡す
                ReportView(targetPostId: post.id.uuidString, targetUserName: authorName)
            }
        }
    }

    // MARK: - 投稿者・投稿日時

    private var authorHeader: some View {
        HStack(spacing: 12) {
            NavigationLink {
                // TODO: 他人のプロフィール画面ができたら差し替える（現状は自分のマイページ）
                ProfileView()
            } label: {
                HStack(spacing: 12) {
                    authorIcon
                    VStack(alignment: .leading, spacing: 2) {
                        Text(authorName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(post.postedAt.formatted(
                            .dateTime.year().month().day().hour().minute()
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // 通報メニュー（Apple審査対策で必須）
            Menu {
                Button(role: .destructive) {
                    isShowingReport = true
                } label: {
                    Label("この投稿を通報する", systemImage: "exclamationmark.triangle")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundStyle(.gray)
                    .padding(8)
            }
        }
    }

    private var authorIcon: some View {
        AsyncImage(url: author?.iconUrl.flatMap(URL.init(string:))) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFill()
                    .foregroundStyle(.gray)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }

    // MARK: - 写真

    private var photo: some View {
        Group {
            if let image = post.image {
                // 投稿直後など、手元に画像がある場合はそのまま表示
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = post.imageUrl.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder(icon: "photo.badge.exclamationmark",
                                    text: "写真を読み込めませんでした")
                    default:
                        placeholder(icon: "photo", text: nil)
                    }
                }
            } else {
                placeholder(icon: "photo", text: "散り桜の写真")
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func placeholder(icon: String, text: String?) -> some View {
        ZStack {
            Color.pink.opacity(0.15)
            VStack(spacing: 8) {
                Image(systemName: icon).font(.largeTitle)
                if let text {
                    Text(text).font(.caption)
                }
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - 場所

    private var placeInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !post.locationName.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill").foregroundStyle(.pink)
                    Text(post.locationName).font(.title3.bold())
                }
            }
            HStack(spacing: 4) {
                Text("エリア:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(post.prefecture)
                    .font(.subheadline.bold())
            }
        }
    }
}

#Preview {
    PostDetailView(
        post: Post(
            location: CLLocation(latitude: 35.6425, longitude: 139.6983),
            prefecture: "東京都",
            locationName: "目黒川沿い",
            comment: "川面に散った桜の花びらがピンクのじゅうたんみたいになっていて綺麗でした！",
            authorName: "さくら太郎"
        )
    )
    .environmentObject(AuthManager.shared)
}
