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

    // MARK: - マイページ用（M-03 自分の投稿一覧）

    /// 指定したユーザーの投稿を新しい順に全件取得する（60日を過ぎてマップから消えたものも含む）
    static func fetchPosts(authorId: UUID) async throws -> [Post] {
        try await client
            .from("posts")
            .select()
            .eq("author_id", value: authorId)
            .order("posted_at", ascending: false)
            .execute()
            .value
    }

    /// 投稿を削除する（自分の投稿のみが対象。RLS側でも本人以外は削除できない前提）
    static func deletePost(id: UUID) async throws {
        try await client
            .from("posts")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// 投稿を編集する（写真・スポット名・コメント。自分の投稿のみが対象）
    static func updatePost(
        id: UUID,
        imageUrl: String?,
        locationName: String,
        comment: String
    ) async throws {
        struct PostUpdate: Encodable {
            let image_url: String?
            let location_name: String?
            let comment: String?
        }
        let update = PostUpdate(
            image_url: imageUrl,
            location_name: locationName.isEmpty ? nil : locationName,
            comment: comment.isEmpty ? nil : comment
        )
        try await client
            .from("posts")
            .update(update)
            .eq("id", value: id)
            .execute()
    }

    // MARK: - ブロック中ユーザー

    /// 自分がブロックしているユーザーIDの一覧を取得する（マップの投稿を絞り込むのに使う）
    static func fetchBlockedUserIds() async throws -> [UUID] {
        let myId = try await client.auth.session.user.id
        struct BlockRow: Decodable {
            let blocked_id: UUID
        }
        let rows: [BlockRow] = try await client
            .from("blocks")
            .select("blocked_id")
            .eq("blocker_id", value: myId)
            .execute()
            .value
        return rows.map { $0.blocked_id }
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
