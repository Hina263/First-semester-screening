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

    /// 必須は「写真」＋「位置情報」のみ。
    /// 現在地モード: GPS座標が取れていればOK（都道府県の入力は不要）
    /// 手動モード: 都道府県の選択が必須（GPSは使わない）
    private var canSubmit: Bool {
        guard selectedImage != nil, !isPosting else { return false }
        return useCurrentLocation
            ? locationManager.roundedLocation != nil
            : !prefecture.isEmpty
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
                // 現在地モードの時だけ位置情報取得関数を起動する
                if useCurrentLocation {
                    locationManager.requestPermission()
                    locationManager.requestLocation()
                }
            }
            .onChange(of: useCurrentLocation) { _, isOn in
                if isOn {
                    // 手動で選んでいた都道府県はリセットし、GPSからの自動判定に切り替える
                    prefecture = ""
                    locationManager.requestPermission()
                    locationManager.requestLocation()
                }
            }
            .onChange(of: locationManager.rawLocation?.latitude) { _, _ in
                guard useCurrentLocation else { return }
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
                // IME変換中に同期的に書き換えると変換が壊れるため、1サイクル遅らせて反映する
                if new.count > maxSpotNameLength {
                    DispatchQueue.main.async {
                        spotName = String(new.prefix(maxSpotNameLength))
                    }
                }
            }

            Toggle(isOn: $useCurrentLocation) {
                HStack {
                    Image(systemName: "location.fill").foregroundStyle(.blue)
                    Text("現在地をスポット座標に設定")
                }
            }

            // 現在地モードの時は都道府県の手動選択は不要（GPSから自動判定するため非表示）
            if !useCurrentLocation {
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
            }
        } header: {
            Text("スポット情報")
        } footer: {
            if useCurrentLocation {
                if locationManager.roundedLocation != nil {
                    Text("※現在地を約100m四方に丸めた座標を保存します。")
                } else {
                    Text("※現在地を取得中です。取得できない場合は、トグルをオフにして都道府県を選択してください。")
                }
            } else {
                Text("※GPSは使わず、選んだ都道府県の代表地点を座標として保存します。")
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
                // IME変換中に同期的に書き換えると変換が壊れるため、1サイクル遅らせて反映する
                if new.count > maxCommentLength {
                    DispatchQueue.main.async {
                        comment = String(new.prefix(maxCommentLength))
                    }
                }
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
        guard useCurrentLocation, let coordinate = locationManager.rawLocation else { return }

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

            let coordinate: CLLocationCoordinate2D?
            if useCurrentLocation {
                // 現在地モード：GPSで取得し丸め済みの座標をそのまま使う
                coordinate = locationManager.roundedLocation
            } else {
                // 手動モード：GPSは使わず、選んだ都道府県の代表座標を使う。
                // ただし同じ県を選んだ投稿同士が完全に同じ座標へ重なってしまうと
                // 個別ピンが見分けられなくなるため、少しランダムにズラす
                if let center = Self.prefectureCenters[prefecture] {
                    coordinate = Self.jittered(center)
                } else {
                    coordinate = nil
                }
            }

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

    // MARK: - 都道府県の代表座標（手動モードでピンを置く場所）
    // 各県庁所在地付近のおおよその座標。正確な位置情報の代わりに使う簡易マッピング。

    /// 代表座標に半径約0.05度（東京付近で数km程度）のランダムなズレを加える。
    /// 同じ県を手動選択した投稿同士が完全に同じ座標へ重ならないようにするため。
    private static func jittered(_ coordinate: CLLocationCoordinate2D, radius: Double = 0.05) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: coordinate.latitude + Double.random(in: -radius...radius),
            longitude: coordinate.longitude + Double.random(in: -radius...radius)
        )
    }

    static let prefectureCenters: [String: CLLocationCoordinate2D] = [
        "北海道": .init(latitude: 43.0642, longitude: 141.3469),
        "青森県": .init(latitude: 40.8244, longitude: 140.7400),
        "岩手県": .init(latitude: 39.7036, longitude: 141.1527),
        "宮城県": .init(latitude: 38.2688, longitude: 140.8721),
        "秋田県": .init(latitude: 39.7186, longitude: 140.1024),
        "山形県": .init(latitude: 38.2404, longitude: 140.3633),
        "福島県": .init(latitude: 37.7503, longitude: 140.4676),
        "茨城県": .init(latitude: 36.3418, longitude: 140.4468),
        "栃木県": .init(latitude: 36.5658, longitude: 139.8836),
        "群馬県": .init(latitude: 36.3907, longitude: 139.0604),
        "埼玉県": .init(latitude: 35.8617, longitude: 139.6455),
        "千葉県": .init(latitude: 35.6073, longitude: 140.1063),
        "東京都": .init(latitude: 35.6895, longitude: 139.6917),
        "神奈川県": .init(latitude: 35.4478, longitude: 139.6425),
        "新潟県": .init(latitude: 37.9026, longitude: 139.0232),
        "富山県": .init(latitude: 36.6953, longitude: 137.2113),
        "石川県": .init(latitude: 36.5947, longitude: 136.6256),
        "福井県": .init(latitude: 36.0652, longitude: 136.2216),
        "山梨県": .init(latitude: 35.6642, longitude: 138.5685),
        "長野県": .init(latitude: 36.6513, longitude: 138.1810),
        "岐阜県": .init(latitude: 35.3912, longitude: 136.7223),
        "静岡県": .init(latitude: 34.9769, longitude: 138.3831),
        "愛知県": .init(latitude: 35.1802, longitude: 136.9066),
        "三重県": .init(latitude: 34.7303, longitude: 136.5086),
        "滋賀県": .init(latitude: 35.0045, longitude: 135.8686),
        "京都府": .init(latitude: 35.0212, longitude: 135.7556),
        "大阪府": .init(latitude: 34.6863, longitude: 135.5200),
        "兵庫県": .init(latitude: 34.6913, longitude: 135.1830),
        "奈良県": .init(latitude: 34.6851, longitude: 135.8049),
        "和歌山県": .init(latitude: 34.2260, longitude: 135.1675),
        "鳥取県": .init(latitude: 35.5039, longitude: 134.2381),
        "島根県": .init(latitude: 35.4723, longitude: 133.0505),
        "岡山県": .init(latitude: 34.6618, longitude: 133.9350),
        "広島県": .init(latitude: 34.3966, longitude: 132.4596),
        "山口県": .init(latitude: 34.1859, longitude: 131.4714),
        "徳島県": .init(latitude: 34.0658, longitude: 134.5593),
        "香川県": .init(latitude: 34.3401, longitude: 134.0434),
        "愛媛県": .init(latitude: 33.8417, longitude: 132.7658),
        "高知県": .init(latitude: 33.5597, longitude: 133.5311),
        "福岡県": .init(latitude: 33.6064, longitude: 130.4181),
        "佐賀県": .init(latitude: 33.2494, longitude: 130.2989),
        "長崎県": .init(latitude: 32.7448, longitude: 129.8737),
        "熊本県": .init(latitude: 32.7898, longitude: 130.7417),
        "大分県": .init(latitude: 33.2382, longitude: 131.6126),
        "宮崎県": .init(latitude: 31.9111, longitude: 131.4239),
        "鹿児島県": .init(latitude: 31.5602, longitude: 130.5581),
        "沖縄県": .init(latitude: 26.2124, longitude: 127.6809)
    ]
}

#Preview {
    CreatePostView()
}
