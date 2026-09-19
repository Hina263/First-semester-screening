//
//  CreatePostView.swift
//  NAGORI
//
//  M-04 写真選択 / M-06 エリア指定＆投稿送信　担当: まなと
//

import SwiftUI
import UIKit
import PhotosUI
import CoreLocation

struct CreatePostView: View {

    /// 投稿成功時に呼ばれる（マップ側でピンを増やすのに使う）
    var onPosted: ((Post) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()

    // 入力内容
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var prefecture = ""
    @State private var spotName = ""
    @State private var comment = ""
    @State private var useCurrentLocation = true

    // 状態
    @State private var isPosting = false
    @State private var errorMessage: String?

    private let maxSpotNameLength = 30
    private let maxCommentLength = 140

    /// 必須は「写真」と「都道府県」のみ（スポット名・コメントは任意）
    private var canSubmit: Bool {
        selectedImage != nil && !prefecture.isEmpty && !isPosting
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                spotSection
                commentSection
            }
            .navigationTitle("桜スポットを投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isPosting {
                            ProgressView()
                        } else {
                            Text("投稿する").bold()
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
            .disabled(isPosting)
            .alert("エラー", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .task {
                // M-05: 画面を開いたタイミングで現在地を取りにいく（拒否されても投稿は可能）
                locationManager.requestPermission()
                locationManager.requestLocation()
            }
            .onChange(of: locationManager.rawLocation?.latitude) { _, _ in
                Task { await fillPrefectureFromLocation() }
            }
        }
    }

    // MARK: - 写真（M-04）

    private var photoSection: some View {
        Section("写真") {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .topTrailing) {
                            Text("変更")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.6), in: Capsule())
                                .padding(8)
                        }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.pink)
                        Text("タップして桜の写真を選択")
                            .font(.subheadline.bold())
                        Text("写真ライブラリから一枚選んでください")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(Color.pink.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.pink.opacity(0.3),
                                    style: StrokeStyle(lineWidth: 1, dash: [6]))
                    }
                }
            }
            .buttonStyle(.plain)
            .onChange(of: pickerItem) { _, newItem in
                Task {
                    guard let data = try? await newItem?.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        errorMessage = "写真を読み込めませんでした"
                        return
                    }
                    selectedImage = image
                }
            }
        }
    }

    // MARK: - スポット情報（M-06）

    private var spotSection: some View {
        Section {
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Image(systemName: "mappin.circle.fill").foregroundStyle(.pink)
                    TextField("スポット名（例: 目黒川、上野公園）", text: $spotName)
                }
                counter(count: spotName.count, limit: maxSpotNameLength)
            }
            .onChange(of: spotName) { _, new in
                if new.count > maxSpotNameLength { spotName = String(new.prefix(maxSpotNameLength)) }
            }

            Toggle(isOn: $useCurrentLocation) {
                HStack {
                    Image(systemName: "location.fill").foregroundStyle(.blue)
                    Text("現在地をスポット座標に設定")
                }
            }

            Picker(selection: $prefecture) {
                Text("選択してください").tag("")
                ForEach(Self.prefectures, id: \.self) { Text($0).tag($0) }
            } label: {
                HStack {
                    Image(systemName: "map.fill").foregroundStyle(.orange)
                    Text("都道府県")
                    if prefecture.isEmpty {
                        Text("(必須)").font(.caption).foregroundStyle(.red)
                    }
                }
            }
        } header: {
            Text("スポット情報")
        } footer: {
            if useCurrentLocation {
                if locationManager.roundedLocation != nil {
                    Text("※現在地を約100m四方に丸めた座標を保存します。")
                } else {
                    Text("※現在地を取得中です。取得できない場合も、都道府県を選べば投稿できます。")
                }
            }
        }
    }

    // MARK: - コメント

    private var commentSection: some View {
        Section("コメント・散り状況") {
            VStack(alignment: .trailing, spacing: 4) {
                TextField(
                    "桜の散り状況や感想を入力（例: 満開を過ぎて綺麗な桜吹雪になっていました！）",
                    text: $comment,
                    axis: .vertical
                )
                .lineLimit(4...8)
                counter(count: comment.count, limit: maxCommentLength)
            }
            .onChange(of: comment) { _, new in
                if new.count > maxCommentLength { comment = String(new.prefix(maxCommentLength)) }
            }
        }
    }

    private func counter(count: Int, limit: Int) -> some View {
        Text("\(count)/\(limit)")
            .font(.caption2)
            .foregroundStyle(count >= limit ? .red : .secondary)
    }

    // MARK: - 逆ジオコーディング（座標 → 都道府県の自動入力）

    @MainActor
    private func fillPrefectureFromLocation() async {
        guard prefecture.isEmpty,
              let coordinate = locationManager.rawLocation else { return }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(
            location, preferredLocale: Locale(identifier: "ja_JP")
        )
        if let area = placemarks?.first?.administrativeArea, Self.prefectures.contains(area) {
            prefecture = area
        }
    }

    // MARK: - 投稿送信

    @MainActor
    private func submit() async {
        guard let image = selectedImage else { return }
        isPosting = true
        defer { isPosting = false }

        do {
            // 長辺2048px / JPEG 0.85 にリサイズしてからアップロード
            guard let data = ImageResizer.jpegData(from: image) else {
                throw PostError.imageEncodingFailed
            }
            let imageUrl = try await PostService.uploadImage(data)

            // 丸め済みの座標を使う（トグルOFF・取得失敗時はnil = 位置情報なしで投稿）
            let coordinate = useCurrentLocation ? locationManager.roundedLocation : nil

            var post = try await PostService.createPost(
                imageUrl: imageUrl,
                coordinate: coordinate,
                prefecture: prefecture,
                locationName: spotName.trimmingCharacters(in: .whitespaces),
                comment: comment.trimmingCharacters(in: .whitespaces)
            )
            post.image = image   // 投稿直後は取得し直さずそのまま表示する
            post.authorName = AuthManager.shared.currentProfile?.userName ?? "匿名"

            onPosted?(post)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 都道府県リスト

    static let prefectures = [
        "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
        "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
        "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県",
        "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県",
        "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県",
        "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県",
        "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
    ]
}

#Preview {
    CreatePostView()
}
