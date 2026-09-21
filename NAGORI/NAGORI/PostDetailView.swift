//
//  PostDetailView.swift
//  NAGORI
//
//  M-10 投稿詳細表示　担当: まなと
//  写真・投稿者・コメント・投稿日時・場所を表示する。投稿者タップでプロフィールへ。
//  自分の投稿の場合はこの画面内でそのまま編集・削除ができる。
//

import SwiftUI
import PhotosUI
import CoreLocation

struct PostDetailView: View {

    /// 削除に成功した時に呼ばれる（マップ/マイページ側でローカルの一覧から取り除くのに使う）
    var onDeleted: ((Post) -> Void)? = nil
    /// 編集に成功した時に呼ばれる（マップ/マイページ側でローカルの一覧を更新するのに使う）
    var onUpdated: ((Post) -> Void)? = nil
    /// ブロックに成功した時に呼ばれる（マップ側でそのユーザーの投稿をその場で取り除くのに使う）
    var onBlocked: ((UUID) -> Void)? = nil

    @State private var post: Post

    init(
        post: Post,
        onDeleted: ((Post) -> Void)? = nil,
        onUpdated: ((Post) -> Void)? = nil,
        onBlocked: ((UUID) -> Void)? = nil
    ) {
        _post = State(initialValue: post)
        self.onDeleted = onDeleted
        self.onUpdated = onUpdated
        self.onBlocked = onBlocked
    }

    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var author: UserProfile?

    // 通報・削除
    @State private var isShowingReport = false
    @State private var isShowingActionSheet = false
    @State private var isShowingDeleteConfirm = false
    @State private var isShowingDeletedAlert = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var isShowingAuthorProfile = false

    // 編集
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var editedLocationName = ""
    @State private var editedComment = ""
    @State private var editedImage: UIImage? = nil
    @State private var pickerItem: PhotosPickerItem?

    private let maxSpotNameLength = 30
    private let maxCommentLength = 140

    /// 取得できるまでは投稿に入っている名前を出しておく
    private var authorName: String {
        author?.userName ?? post.authorName
    }

    /// 自分自身の投稿かどうか（自分の投稿は通報できない代わりに編集・削除ができる）
    private var isOwnPost: Bool {
        guard let authorId = post.authorId, let myId = auth.currentProfile?.id else { return false }
        return authorId == myId
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    authorHeader
                    photo
                    placeInfo

                    if isEditing {
                        Divider()
                        VStack(alignment: .trailing, spacing: 4) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("投稿コメント")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField(
                                    "桜の散り状況や感想を入力",
                                    text: $editedComment,
                                    axis: .vertical
                                )
                                .lineLimit(4...8)
                            }
                            Text("\(editedComment.count)/\(maxCommentLength)")
                                .font(.caption2)
                                .foregroundStyle(editedComment.count >= maxCommentLength ? .red : .secondary)
                        }
                        .onChange(of: editedComment) { _, new in
                            // IME変換中に同期的に書き換えると変換が壊れるため、1サイクル遅らせて反映する
                            if new.count > maxCommentLength {
                                DispatchQueue.main.async {
                                    editedComment = String(new.prefix(maxCommentLength))
                                }
                            }
                        }
                    } else if !post.comment.isEmpty {
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
                if isEditing {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("キャンセル") { cancelEditing() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isSaving ? "保存中..." : "保存") {
                            Task { await saveEdits() }
                        }
                        .bold()
                        .disabled(isSaving)
                    }
                } else {
                    // 「閉じる」は確実にタップが効いているので、プロフィール・•••も同じツールバー上に置く
                    // ※iOS26は同じ場所のToolbarItemを自動でグループ化してハイライトも共有してしまうため、
                    //   ToolbarSpacer(.fixed)で明示的に別グループに分離する
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isShowingAuthorProfile = true
                        } label: {
                            Image(systemName: "person.crop.circle")
                        }
                    }
                    if #available(iOS 26.0, *) {
                        ToolbarSpacer(.fixed, placement: .topBarLeading)
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isShowingActionSheet = true
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("閉じる") { dismiss() }
                    }
                }
            }
            .disabled(isDeleting || isSaving)
            .overlay {
                if isDeleting {
                    ProgressView("削除中...")
                        .padding(20)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .task {
                guard let authorId = post.authorId else { return }
                author = try? await PostService.fetchAuthor(id: authorId)
            }
            .onChange(of: pickerItem) { _, newItem in
                Task {
                    guard let data = try? await newItem?.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    editedImage = image
                }
            }
            .sheet(isPresented: $isShowingReport) {
                // M-12（てるる担当）の通報画面へ投稿ID・対象ユーザーIDを渡す
                ReportView(
                    targetPostId: post.id.uuidString,
                    targetUserId: post.authorId,
                    targetUserName: authorName,
                    onBlocked: onBlocked
                )
            }
            .sheet(isPresented: $isShowingAuthorProfile) {
                NavigationStack {
                    if isOwnPost {
                        ProfileView()
                    } else if let authorId = post.authorId {
                        UserProfileView(userId: authorId)
                    } else {
                        ContentUnavailableView(
                            "ユーザー情報を取得できませんでした",
                            systemImage: "person.crop.circle.badge.exclamationmark"
                        )
                    }
                }
            }
            .confirmationDialog(
                "投稿を操作",
                isPresented: $isShowingActionSheet,
                titleVisibility: .hidden
            ) {
                if isOwnPost {
                    Button("この投稿を編集する") {
                        startEditing()
                    }
                    Button("この投稿を削除する", role: .destructive) {
                        isShowingDeleteConfirm = true
                    }
                } else {
                    Button("この投稿を通報する", role: .destructive) {
                        isShowingReport = true
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
            .confirmationDialog(
                "この投稿を削除しますか？",
                isPresented: $isShowingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("削除する", role: .destructive) {
                    Task { await deletePost() }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("削除すると元に戻せません。")
            }
            .alert("投稿を削除しました", isPresented: $isShowingDeletedAlert) {
                Button("OK") {
                    onDeleted?(post)
                    dismiss()
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
        }
    }

    // MARK: - 投稿者・投稿日時（表示のみ。タップはツールバーのアイコンから）

    private var authorHeader: some View {
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

            Spacer()
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

    // MARK: - 写真（編集中はカメラマークをタップして差し替え可能）

    private var photo: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let editedImage {
                    // 編集中に新しく選んだ写真を優先して表示
                    Image(uiImage: editedImage)
                        .resizable()
                        .scaledToFill()
                } else if let image = post.image {
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

            if isEditing {
                // プロフィール編集のアイコン変更ボタンと同じ見た目のカメラマーク
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(Color.black)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
                .padding(10)
            }
        }
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

    // MARK: - 場所（スポット名は編集中のみTextFieldになる）

    private var placeInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditing {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill").foregroundStyle(.pink)
                        TextField("スポット名（例: 目黒川、上野公園）", text: $editedLocationName)
                            .font(.title3.bold())
                    }
                    Text("\(editedLocationName.count)/\(maxSpotNameLength)")
                        .font(.caption2)
                        .foregroundStyle(editedLocationName.count >= maxSpotNameLength ? .red : .secondary)
                }
                .onChange(of: editedLocationName) { _, new in
                    // IME変換中に同期的に書き換えると変換が壊れるため、1サイクル遅らせて反映する
                    if new.count > maxSpotNameLength {
                        DispatchQueue.main.async {
                            editedLocationName = String(new.prefix(maxSpotNameLength))
                        }
                    }
                }
            } else if !post.locationName.isEmpty {
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

    // MARK: - 編集

    private func startEditing() {
        editedLocationName = post.locationName
        editedComment = post.comment
        editedImage = nil
        pickerItem = nil
        isEditing = true
    }

    private func cancelEditing() {
        isEditing = false
        editedImage = nil
        pickerItem = nil
    }

    @MainActor
    private func saveEdits() async {
        isSaving = true
        defer { isSaving = false }
        do {
            var newImageUrl = post.imageUrl
            if let editedImage {
                guard let data = ImageResizer.jpegData(from: editedImage) else {
                    throw PostError.imageEncodingFailed
                }
                newImageUrl = try await PostService.uploadImage(data)
            }

            let trimmedName = editedLocationName.trimmingCharacters(in: .whitespaces)
            let trimmedComment = editedComment.trimmingCharacters(in: .whitespaces)

            try await PostService.updatePost(
                id: post.id,
                imageUrl: newImageUrl,
                locationName: trimmedName,
                comment: trimmedComment
            )

            post.locationName = trimmedName
            post.comment = trimmedComment
            if let editedImage {
                post.image = editedImage   // 保存直後は再取得せず手元の画像をそのまま表示
                post.imageUrl = newImageUrl
            }
            onUpdated?(post)

            isEditing = false
            self.editedImage = nil
            pickerItem = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 削除

    @MainActor
    private func deletePost() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await PostService.deletePost(id: post.id)
            isShowingDeletedAlert = true
        } catch {
            errorMessage = error.localizedDescription
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
