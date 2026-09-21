//
//  MainMapView.swift
//  NAGORI
//
//  M-07 / M-08 マップ表示（ピン・60日での色分け・クラスタリング・都道府県フィルタ）担当: すみー
//

import SwiftUI
import MapKit
import CoreLocation

struct MainMapView: View {
    // デフォルトの表示範囲：五反田駅付近を中心に、東北〜東海がざっくり入るくらいの広さ
    // （現在地が取得できるまでの間、または取得できない場合のフォールバックとしても使う）
    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6262, longitude: 139.7238),
        span: MKCoordinateSpan(latitudeDelta: 6.0, longitudeDelta: 5.0)
    )
    private static let minZoomDelta = 0.005
    // ＋−ボタンでのズームアウトは日本全体がだいたい入るくらいまでに制限する
    private static let maxZoomDelta = 25.0
    // これより広い範囲を表示している間は、ピンを都道府県ごとにクラスタ表示する
    private static let clusterThreshold = 0.20

    @State private var cameraPosition: MapCameraPosition = .region(defaultRegion)
    // ＋／−ボタンでズームしたり、クラスタ表示に切り替えたりするために、現在地表示中のregionを追跡しておく
    @State private var visibleRegion: MKCoordinateRegion = defaultRegion

    // 現在地取得（起動時に一度だけ、取得できたらそこを中心に移動する）
    @StateObject private var locationManager = LocationManager()
    @State private var hasCenteredOnCurrentLocation = false

    // 絞り込み条件
    @State private var selectedPrefecture: String = "すべて"
    @State private var selectedPeriod: String = "すべて"

    // sheetの状態を1つにまとめる（別々のBool/Optionalを複数持つと
    // タイミングによって二重に開いてしまうことがあるため）
    private enum ActiveSheet: Identifiable {
        case createPost
        case myPage
        case filter
        case postDetail(Post)

        var id: String {
            switch self {
            case .createPost: return "createPost"
            case .myPage: return "myPage"
            case .filter: return "filter"
            case .postDetail(let post): return "postDetail-\(post.id.uuidString)"
            }
        }
    }
    @State private var activeSheet: ActiveSheet?

    // Post データ（Supabaseから取得した実データ）
    @State private var posts: [Post] = []
    @State private var isLoadingPosts = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                // MARK: - Map
                Map(position: $cameraPosition) {
                    if shouldCluster {
                        // MARK: ズームアウト時：都道府県ごとにクラスタ表示
                        ForEach(clusteredPosts) { cluster in
                            Annotation(cluster.prefecture, coordinate: cluster.coordinate) {
                                Button {
                                    zoomToCluster(cluster)
                                } label: {
                                    ZStack {
                                        Circle().fill(Color.pink)
                                        Circle().stroke(Color.white, lineWidth: 3)
                                        Text("\(cluster.count)")
                                            .font(.system(size: max(clusterDiameter * 0.32, 11), weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    .frame(width: clusterDiameter, height: clusterDiameter)
                                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                                }
                            }
                        }
                    } else {
                        // MARK: ズームイン時：投稿ごとの個別ピン
                        ForEach(filteredPosts) { post in
                            Annotation(post.locationName, coordinate: post.coordinate) {
                                Button {
                                    activeSheet = .postDetail(post)
                                } label: {
                                    Image(systemName: "line.3.crossed.swirl.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(post.pinColor)
                                        .background(Circle().fill(.white))
                                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                                }
                            }
                        }
                    }
                }
                // 3D切り替え・コンパス・現在地ボタン（iOSで使えるMapKit純正コントロール）
                .mapControls {
                    MapPitchToggle()
                    MapCompass()
                    MapUserLocationButton()
                }
                .onMapCameraChange(frequency: .continuous) { context in
                    visibleRegion = context.region
                }
                // フィルタ条件が変わったら、Mapを強制的に作り直して描画キャッシュの古さを防ぐ
                .id("\(selectedPrefecture)-\(selectedPeriod)")

                // MARK: - ズームボタン（＋／−）
                // MapZoomStepperはmacOS/Catalyst専用でiOSには存在しないため自前で実装
                zoomStepper
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 170)
                    .padding(.trailing, 10)

                // MARK: - 右下ボタン（フィルタ・投稿）
                VStack(spacing: 14) {
                    Button {
                        activeSheet = .filter
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(isFilterActive ? .white : .pink)
                            .frame(width: 50, height: 50)
                            .background(isFilterActive ? Color.pink : Color.white)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                    }

                    Button {
                        activeSheet = .createPost
                    } label: {
                        Image(systemName: "plus")
                            .font(.title.bold())
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.pink)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("桜マップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        activeSheet = .myPage
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.title3)
                            .foregroundColor(.pink)
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .createPost:
                    CreatePostView { newPost in
                        posts.insert(newPost, at: 0)
                    }
                case .myPage:
                    NavigationStack {
                        ProfileView()
                    }
                case .filter:
                    FilterView(
                        selectedPrefecture: $selectedPrefecture,
                        selectedPeriod: $selectedPeriod
                    )
                    .presentationDetents([.medium])
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
                            posts.removeAll { $0.authorId == blockedUserId }
                        }
                    )
                    .presentationDetents([.large])
                }
            }
            .task {
                await loadPosts()
                // 現在地を取得できたら、一度だけそこを中心に移動する（以降はユーザー操作を優先）
                locationManager.requestPermission()
                locationManager.requestLocation()
            }
            .onChange(of: locationManager.rawLocation?.latitude) { _, _ in
                guard !hasCenteredOnCurrentLocation, let coordinate = locationManager.rawLocation else { return }
                hasCenteredOnCurrentLocation = true
                let region = MKCoordinateRegion(center: coordinate, span: Self.defaultRegion.span)
                visibleRegion = region
                withAnimation {
                    cameraPosition = .region(region)
                }
            }
        }
    }

    // MARK: - 絞り込み・クラスタリング

    /// 60日以内・座標あり・都道府県/投稿時期フィルタを満たす投稿
    private var filteredPosts: [Post] {
        let result = posts.filter { post in
            guard post.isFresh, post.hasCoordinate else { return false }

            let prefectureOK = selectedPrefecture == "すべて" || post.prefecture == selectedPrefecture

            let days = Calendar.current.dateComponents([.day], from: post.postedAt, to: Date()).day ?? 0
            let periodOK: Bool
            switch selectedPeriod {
            case "7日以内": periodOK = days <= 7
            case "8〜21日": periodOK = days >= 8 && days <= 21
            case "22〜45日": periodOK = days >= 22 && days <= 45
            case "46〜60日": periodOK = days >= 46 && days <= 60
            default: periodOK = true
            }

            return prefectureOK && periodOK
        }
        print("🔍 filter: prefecture=\"\(selectedPrefecture)\" period=\"\(selectedPeriod)\" → \(result.count)/\(posts.count)件")
        for post in posts {
            let days = Calendar.current.dateComponents([.day], from: post.postedAt, to: Date()).day ?? 0
            print("   - \(post.locationName): prefecture=\"\(post.prefecture)\" days=\(days) isFresh=\(post.isFresh) hasCoordinate=\(post.hasCoordinate)")
        }
        return result
    }

    private var isFilterActive: Bool {
        selectedPrefecture != "すべて" || selectedPeriod != "すべて"
    }

    /// 表示範囲が広い（ズームアウトしている）間はクラスタ表示に切り替える
    private var shouldCluster: Bool {
        visibleRegion.span.latitudeDelta >= Self.clusterThreshold
    }

    /// クラスタの円のサイズを表示範囲の広さに応じて滑らかに変える。
    /// 個別ピンに切り替わる閾値に近い（クラスタの中では一番ズームインしてる）ほど大きく、
    /// ズームアウトするほど小さくなり、maxDelta以上広い表示では最小サイズで固定する
    private var clusterDiameter: CGFloat {
        let minDelta = Self.clusterThreshold  // これ未満で個別ピンに切り替わる → ここが最大サイズ
        let maxDelta = 20.0                   // これ以上広い表示では最小サイズのまま固定する
        let minSize: CGFloat = 18
        let maxSize: CGFloat = 56

        let clamped = min(max(visibleRegion.span.latitudeDelta, minDelta), maxDelta)
        let ratio = (clamped - minDelta) / (maxDelta - minDelta)
        // ratioが0(閾値付近・一番ズームイン)→maxSize、ratioが1(広い表示)→minSizeになるよう反転
        return maxSize - (maxSize - minSize) * CGFloat(ratio)
    }

    /// 都道府県ごとにまとめたクラスタ（位置はCreatePostViewの都道府県代表座標を使う。
    /// 投稿座標の平均だと、投稿が県内でバラけている時に変な位置になってしまうため）
    private var clusteredPosts: [PrefectureCluster] {
        let grouped = Dictionary(grouping: filteredPosts) { $0.prefecture }

        return grouped.compactMap { prefecture, posts in
            guard !posts.isEmpty else { return nil }

            let coordinate: CLLocationCoordinate2D
            if let center = CreatePostView.prefectureCenters[prefecture] {
                coordinate = center
            } else {
                // 代表座標が無い県名（データ不整合など）は投稿座標の平均でフォールバック
                let averageLatitude = posts.map { $0.coordinate.latitude }.reduce(0, +) / Double(posts.count)
                let averageLongitude = posts.map { $0.coordinate.longitude }.reduce(0, +) / Double(posts.count)
                coordinate = CLLocationCoordinate2D(latitude: averageLatitude, longitude: averageLongitude)
            }

            return PrefectureCluster(
                prefecture: prefecture,
                posts: posts,
                coordinate: coordinate
            )
        }
    }

    /// クラスタタップ時：そのクラスタに含まれる投稿が全部収まる範囲までズームする
    private func zoomToCluster(_ cluster: PrefectureCluster) {
        let coordinates = cluster.posts.map { $0.coordinate }
        guard !coordinates.isEmpty else { return }

        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        let minLat = latitudes.min()!
        let maxLat = latitudes.max()!
        let minLon = longitudes.min()!
        let maxLon = longitudes.max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        // ピンが端ギリギリにならないよう30%の余白を持たせる。
        // 全ピンが同じ場所の場合でも最低限のズーム幅は確保する
        let padding = 1.3
        let latDelta = max((maxLat - minLat) * padding, 0.02)
        let lonDelta = max((maxLon - minLon) * padding, 0.02)

        // 右下の🔍・＋ボタンとピンが被らないよう、中心を少し南（画面下方向）にずらして
        // ピン全体が画面の上寄りに収まるようにする
        let verticalBias = latDelta * 0.15
        let biasedCenter = CLLocationCoordinate2D(
            latitude: center.latitude - verticalBias,
            longitude: center.longitude
        )

        let region = MKCoordinateRegion(
            center: biasedCenter,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
        visibleRegion = region
        withAnimation {
            cameraPosition = .region(region)
        }
    }

    // MARK: - ズームボタンのUI

    private var zoomStepper: some View {
        VStack(spacing: 0) {
            Button {
                zoom(by: 0.5) // ＋：範囲を半分にして拡大
            } label: {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            Divider().frame(width: 30)
            Button {
                zoom(by: 2.0) // −：範囲を倍にして縮小
            } label: {
                Image(systemName: "minus")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
        }
        .foregroundStyle(.primary)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
    }

    private func zoom(by factor: Double) {
        var region = visibleRegion
        region.span.latitudeDelta = min(max(region.span.latitudeDelta * factor, Self.minZoomDelta), Self.maxZoomDelta)
        region.span.longitudeDelta = min(max(region.span.longitudeDelta * factor, Self.minZoomDelta), Self.maxZoomDelta)
        visibleRegion = region
        withAnimation {
            cameraPosition = .region(region)
        }
    }

    // MARK: - Supabaseから投稿一覧を取得

    private func loadPosts() async {
        isLoadingPosts = true
        defer { isLoadingPosts = false }
        do {
            let fetchedPosts = try await PostService.fetchRecentPosts()
            // ブロック中のユーザーの投稿はマップに出さない
            var blockedIds: [UUID] = []
            do {
                blockedIds = try await PostService.fetchBlockedUserIds()
            } catch {
                print("⚠️ ブロック中ユーザーの取得に失敗しました（blocksテーブルのSQL未実行の可能性）: \(error.localizedDescription)")
            }
            posts = blockedIds.isEmpty
                ? fetchedPosts
                : fetchedPosts.filter { post in
                    guard let authorId = post.authorId else { return true }
                    return !blockedIds.contains(authorId)
                }
        } catch {
            print("投稿一覧の取得に失敗しました: \(error.localizedDescription)")
        }
    }
}

/// 都道府県ごとのピンまとめ表示用
struct PrefectureCluster: Identifiable {
    let id = UUID()
    let prefecture: String
    let posts: [Post]
    let coordinate: CLLocationCoordinate2D

    var count: Int { posts.count }
}

#Preview {
    MainMapView()
}
