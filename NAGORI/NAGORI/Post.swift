//
//  Post.swift
//  NAGORI
//
//  M-04 / M-06 / M-10 担当: まなと
//  postsテーブルの1行を表すモデル。MainMapView の暫定スタブを置き換えたもの。
//

import SwiftUI
import UIKit
import CoreLocation

struct Post: Identifiable, Decodable {

    // MARK: - postsテーブルのカラム
    let id: UUID
    var authorId: UUID?
    var imageUrl: String?
    var latitude: Double?
    var longitude: Double?
    var prefecture: String
    var locationName: String
    var comment: String
    var postedAt: Date

    // MARK: - 画面表示用（DBには無い）
    var authorName: String = "匿名"
    var image: UIImage? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case imageUrl = "image_url"
        case latitude
        case longitude
        case prefecture
        case locationName = "location_name"
        case comment
        case postedAt = "posted_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        authorId = try c.decodeIfPresent(UUID.self, forKey: .authorId)
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        prefecture = try c.decodeIfPresent(String.self, forKey: .prefecture) ?? ""
        locationName = try c.decodeIfPresent(String.self, forKey: .locationName) ?? ""
        comment = try c.decodeIfPresent(String.self, forKey: .comment) ?? ""
        postedAt = try c.decode(Date.self, forKey: .postedAt)
    }

    /// 動作確認用ダミーデータや、投稿直後の表示に使う初期化
    init(
        id: UUID = UUID(),
        location: CLLocation?,
        prefecture: String,
        locationName: String,
        comment: String,
        postedAt: Date = Date(),
        authorId: UUID? = nil,
        authorName: String = "匿名",
        imageUrl: String? = nil,
        image: UIImage? = nil
    ) {
        self.id = id
        self.latitude = location?.coordinate.latitude
        self.longitude = location?.coordinate.longitude
        self.prefecture = prefecture
        self.locationName = locationName
        self.comment = comment
        self.postedAt = postedAt
        self.authorId = authorId
        self.authorName = authorName
        self.imageUrl = imageUrl
        self.image = image
    }

    // MARK: - マップ表示用ヘルパー

    /// 座標を持っているか（位置情報を拒否して投稿された場合は false → マップには出さない）
    var hasCoordinate: Bool {
        latitude != nil && longitude != nil
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude ?? 0, longitude: longitude ?? 0)
    }

    /// 投稿からの経過日数
    var daysSincePosted: Int {
        Calendar.current.dateComponents([.day], from: postedAt, to: Date()).day ?? 0
    }

    /// 60日以内の投稿か（60日超はマップ非表示）
    var isFresh: Bool {
        daysSincePosted <= 60
    }

    /// 経過日数に応じたピンの色（M-08 すみー担当のロジックをそのまま引き継いでいます）
    var pinColor: Color {
        switch daysSincePosted {
        case 0...7:   return .pink
        case 8...21:  return .pink.opacity(0.5)
        case 22...45: return .brown.opacity(0.7)
        default:      return .brown
        }
    }
}
