//
//  ProfileEditView.swift
//  NAGORI
//
//  プロフィール編集（シートで表示）。名前とアイコンのみ編集可能。
//

import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var userName: String = ""
    @State private var isSaving = false

    // アイコン画像関連
    @State private var selectedItem: PhotosPickerItem?
    @State private var previewImage: Image?
    @State private var pendingImageData: Data?
    @State private var isUploadingAvatar = false

    private var canSubmit: Bool {
        !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                avatarPicker
                    .padding(.top, 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text("基本情報")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("名前")
                        Spacer()
                        TextField("名前", text: $userName)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                if let message = auth.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("プロフィール編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中..." : "保存") {
                        Task { await save() }
                    }
                    .foregroundStyle(Color.pink)
                    .disabled(!canSubmit)
                }
            }
            .onAppear {
                userName = auth.currentProfile?.userName ?? ""
            }
            .onChange(of: selectedItem) { _, newItem in
                Task { await loadSelectedImage(newItem) }
            }
        }
    }

    // MARK: - アイコン選択UI（アイコン・「写真を変更」どちらでもPickerが開く）

    private var avatarPicker: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        avatarImage
                        if isUploadingAvatar {
                            Color.black.opacity(0.3)
                            ProgressView().tint(.white)
                        }
                    }
                    .frame(width: 110, height: 110)
                    .clipShape(Circle())

                    Image(systemName: "camera.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(Color.black)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }

                Text("写真を変更")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.pink)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let previewImage {
            previewImage
                .resizable()
                .scaledToFill()
        } else if let urlString = auth.currentProfile?.iconUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholderAvatar
                }
            }
        } else {
            placeholderAvatar
        }
    }

    private var placeholderAvatar: some View {
        ZStack {
            Color.pink
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .foregroundStyle(.white)
        }
    }

    // MARK: - 画像読み込み

    @MainActor
    private func loadSelectedImage(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }

        previewImage = Image(uiImage: uiImage)

        let resized = uiImage.resized(maxDimension: 1024)
        pendingImageData = resized.jpegData(compressionQuality: 0.85)
    }

    // MARK: - 保存

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        var iconUrl = auth.currentProfile?.iconUrl

        if let pendingImageData {
            isUploadingAvatar = true
            let uploadedUrl = await auth.uploadAvatar(imageData: pendingImageData)
            isUploadingAvatar = false

            guard let uploadedUrl else {
                // アップロードに失敗した場合はプロフィール保存自体を中断する
                return
            }
            iconUrl = uploadedUrl
        }

        await auth.saveProfile(userName: userName, iconUrl: iconUrl)

        if auth.currentProfile != nil {
            dismiss()
        }
    }
}

// MARK: - 画像リサイズ用ヘルパー

private extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let widthRatio = maxDimension / size.width
        let heightRatio = maxDimension / size.height
        let scale = min(widthRatio, heightRatio, 1.0)
        guard scale < 1.0 else { return self }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

#Preview {
    ProfileEditView()
        .environmentObject(AuthManager.shared)
}
