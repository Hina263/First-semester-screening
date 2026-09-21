//
//  AuthManager.swift
//  NAGORI
//
//  メールアドレス＋パスワードでのログイン/新規登録、プロフィール管理
//

import Foundation
import Combine
import Supabase

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    enum AuthState: Equatable {
        case loading
        case signedOut
        /// ログイン済み。profileがnilなら「まだusersに行がない（=初回）」を意味する
        case signedIn(UserProfile?)
    }

    @Published private(set) var state: AuthState = .loading

    /// 認証/プロフィール操作で起きたエラー。ここが変わってもログイン画面には飛ばない。
    @Published var errorMessage: String?

    /// 今ログイン中のプロフィール（未ログイン/未設定なら nil）
    var currentProfile: UserProfile? {
        if case .signedIn(let profile) = state {
            return profile
        }
        return nil
    }

    private var client: SupabaseClient { SupabaseManager.shared.client }

    private init() {}

    // MARK: - 起動時のセッション確認

    func bootstrap() async {
        do {
            let session = try await client.auth.session
            await loadProfile(userId: session.user.id)
        } catch {
            state = .signedOut
        }
    }

    // MARK: - メール＋パスワード認証

    /// 新規登録
    func signUp(email: String, password: String) async {
        errorMessage = nil
        do {
            let response = try await client.auth.signUp(email: email, password: password)
            if let session = response.session {
                await loadProfile(userId: session.user.id)
            } else {
                await signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// ログイン
    func signIn(email: String, password: String) async {
        errorMessage = nil
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            await loadProfile(userId: session.user.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - プロフィール（usersテーブル）

    func loadProfile(userId: UUID) async {
        do {
            let profile: UserProfile = try await client
                .from("users")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            state = .signedIn(profile)
        } catch {
            // 行が無い（新規ユーザー）場合も、デコード失敗などの場合も、
            // ここでは「プロフィール未設定」として扱う。
            // ただし保存はupsertにしているので、たとえこれが誤判定でも
            // 主キー重複エラーにはならず、既存の行が上書きされるだけで済む。
            state = .signedIn(nil)
        }
    }

    /// プロフィールを保存（無ければ作成、あれば更新）
    func saveProfile(userName: String, iconUrl: String?) async {
        errorMessage = nil
        do {
            let session = try await client.auth.session
            struct UpsertUser: Encodable {
                let id: UUID
                let user_name: String
                let icon_url: String?
            }
            try await client
                .from("users")
                .upsert(UpsertUser(id: session.user.id, user_name: userName, icon_url: iconUrl))
                .execute()
            await loadProfile(userId: session.user.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
        state = .signedOut
    }

    // MARK: - アイコン画像アップロード

    /// 選択した画像データをavatarsバケットにアップロードし、公開URLを返す。
    /// 失敗した場合はnilを返し、呼び出し側はプロフィール保存自体を中断すること。
    func uploadAvatar(imageData: Data) async -> String? {
        errorMessage = nil
        do {
            let session = try await client.auth.session
            let path = "\(session.user.id)/avatar.jpg"

            try await client.storage
                .from("avatars")
                .upload(
                    path,
                    data: imageData,
                    options: FileOptions(contentType: "image/jpeg", upsert: true)
                )

            let publicURL = try client.storage
                .from("avatars")
                .getPublicURL(path: path)

            return publicURL.absoluteString
        } catch {
            errorMessage = "画像のアップロードに失敗しました: \(error.localizedDescription)"
            return nil
        }
    }
}
