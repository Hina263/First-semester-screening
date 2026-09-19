//
//  MainMapView.swift
//  NAGORI
//

import SwiftUI
import MapKit
import CoreLocation

struct MainMapView: View {
    // カメラの初期位置（東京周辺）
        @State private var cameraPosition: MapCameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35.6700, longitude: 139.7500),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )
    
    @State private var selectedPost: Post? = nil
    @State private var isShowingCreatePost: Bool = false
    @State private var isShowingMyPage: Bool = false
    
    // Post データモデル（動作確認用ダミーデータ）
    @State private var posts: [Post] = [
        // 0〜7日以内（真ピンク）
        Post(location: CLLocation(latitude: 35.6431, longitude: 139.6986), prefecture: "東京都", locationName: "目黒川の桜", comment: "満開の桜並木！", postedAt: daysAgo(2)),
        Post(location: CLLocation(latitude: 35.6415, longitude: 139.6998), prefecture: "東京都", locationName: "中目黒公園", comment: "川沿いから少し入った穴場。", postedAt: daysAgo(5)),
        Post(location: CLLocation(latitude: 35.6905, longitude: 139.7503), prefecture: "東京都", locationName: "皇居千鳥ヶ淵", comment: "ボートからの絶景。", postedAt: daysAgo(1)),
        Post(location: CLLocation(latitude: 35.7146, longitude: 139.7733), prefecture: "東京都", locationName: "上野恩賜公園", comment: "大人気の桜名所！", postedAt: daysAgo(0)),
        
        // 8〜21日以内（薄ピンク）
        Post(location: CLLocation(latitude: 35.6490, longitude: 139.6965), prefecture: "東京都", locationName: "西郷山公園", comment: "高台からの見晴らしが良いです。", postedAt: daysAgo(10)),
        Post(location: CLLocation(latitude: 35.6940, longitude: 139.7430), prefecture: "東京都", locationName: "靖国神社", comment: "標本木があります。", postedAt: daysAgo(14)),
        
        // 22〜45日以内（茶色）
        Post(location: CLLocation(latitude: 35.6498, longitude: 139.6950), prefecture: "東京都", locationName: "菅刈公園", comment: "日本庭園と桜のコラボ。", postedAt: daysAgo(30)),
        
        // 46〜60日以内（真茶色）
        Post(location: CLLocation(latitude: 35.6420, longitude: 139.7130), prefecture: "東京都", locationName: "恵比寿ガーデンプレイス", comment: "広場の桜が綺麗です。", postedAt: daysAgo(50)),
        
        // 60日超（非表示テスト）
        Post(location: CLLocation(latitude: 35.6738, longitude: 139.7560), prefecture: "東京都", locationName: "日比谷公園（旧投稿）", comment: "昔の投稿。", postedAt: daysAgo(61))
    ]
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                // MARK: - 1. Map (60日以内の投稿のみをフィルタ表示)
                Map(position: $cameraPosition) {
                    ForEach(posts.filter { $0.isFresh && $0.hasCoordinate }) { post in
                        Annotation(post.locationName, coordinate: post.coordinate) {
                            Button {
                                selectedPost = post
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
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                
                // MARK: - 2. 投稿ボタン (FAB)
                Button {
                    isShowingCreatePost = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title.bold())
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.pink)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("桜マップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingMyPage = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.title3)
                            .foregroundColor(.pink)
                    }
                }
            }
            .sheet(isPresented: $isShowingCreatePost) {
                CreatePostView { newPost in
                    posts.insert(newPost, at: 0)
                }
            }
            .sheet(isPresented: $isShowingMyPage) {
                NavigationStack {
                    ProfileView()
                }
            }
            .sheet(item: $selectedPost) { post in
                PostDetailView(post: post)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

private func daysAgo(_ days: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
}

#Preview {
    MainMapView()
}
