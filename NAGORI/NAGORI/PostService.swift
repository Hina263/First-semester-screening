//
//  PostService.swift
//  NAGORI
//
//  M-04 / M-06 / M-10 担当: まなと
//  投稿まわりのSupabase呼び出しをここに集約する。Viewから直接clientは触らない。
//

import Foundation
import CoreLocation
import Supabase

enum PostService {

    private static var client: SupabaseClient { SupabaseManager.shared.client }
    private static let imageBucket = "posts"

    // MARK: - M-04 写真アップロード

    /// リサイズ済みJPEGをStorageへ保存し、公開URLを返す
    static func uploadImage(_ data: Data) async throws -> String {
        let userId = try await client.auth.session.user.id
        // SwiftのUUIDは大文字、PostgresのRLS（auth.uid()::text）は小文字で比較されるため
        // 小文字に揃えないと「他人のフォルダへの書き込み」と判定されて弾かれる
        let path = "\(userId.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"

        try await client.storage
            .from(imageBucket)
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))

        return try client.storage
            .from(imageBucket)
            .getPublicURL(path: path)
            .absoluteString
    }

    // MARK: - M-06 投稿送信

    /// postsへ1件insertし、保存された投稿を返す。
    /// 座標は LocationManager 側で丸め済みのものを受け取る想定（nilなら位置情報なしで保存）。
    static func createPost(
        imageUrl: String,
        coordinate: CLLocationCoordinate2D?,
        prefecture: String,
        locationName: String,
        comment: String
    ) async throws -> Post {
        let userId = try await client.auth.session.user.id

        struct NewPost: Encodable {
            let author_id: UUID
            let image_url: String
            let latitude: Double?
            let longitude: Double?
            let prefecture: String
            let location_name: String?
            let comment: String?
        }

        let newPost = NewPost(
            author_id: userId,
            image_url: imageUrl,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude,
            prefecture: prefecture,
            location_name: locationName.isEmpty ? nil : locationName,
            comment: comment.isEmpty ? nil : comment
        )

        return try await client
            .from("posts")
            .insert(newPost)
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - M-10 投稿詳細

    /// author_id から投稿者のプロフィールを取得
    static func fetchAuthor(id: UUID) async throws -> UserProfile {
        try await client
            .from("users")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    // MARK: - マップ用（M-07 / M-08 すみー担当が使えるように用意）

    /// 投稿日から指定日数以内の投稿を新しい順に取得
    static func fetchRecentPosts(withinDays days: Int = 60) async throws -> [Post] {
        let since = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return try await client
            .from("posts")
            .select()
            .gte("posted_at", value: since.ISO8601Format())
            .order("posted_at", ascending: false)
            .execute()
            .value
    }
}

// MARK: - エラー

enum PostError: LocalizedError {
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed: return "画像の変換に失敗しました"
        }
    }
}
