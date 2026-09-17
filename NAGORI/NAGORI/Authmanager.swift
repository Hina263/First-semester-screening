//
//  AuthManager.swift
//  NAGORI
//
//  M-01: メールアドレス＋パスワードでのログイン/新規登録
//  M-02の前提となるログイン状態管理
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
        case needsProfileSetup   // 認証は成功したが、usersテーブルに未登録
        case signedIn(UserProfile)
        case failed(String)
    }

    @Published private(set) var state: AuthState = .loading

    private var client: SupabaseClient { SupabaseManager.shared.client }

    private init() {}

    // 起動時のセッション確認

    func bootstrap() async {
        do {
            let session = try await client.auth.session
            await loadProfile(userId: session.user.id)
        } catch {
            state = .signedOut
        }
    }

    //  メール＋パスワード認証

    /// 新規登録
    func signUp(email: String, password: String) async {
        do {
            let response = try await client.auth.signUp(email: email, password: password)
            if let session = response.session {
                await loadProfile(userId: session.user.id)
            } else {
                // 通常はConfirm email OFFなら即座にsessionが返る。
                // 返らない場合はそのままサインインを試みる（多くはこれで通る）
                await signIn(email: email, password: password)
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// ログイン
    func signIn(email: String, password: String) async {
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            await loadProfile(userId: session.user.id)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    //  プロフィール（usersテーブル）

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
            // usersに該当行がない = 初回ログイン → M-02の初期設定画面へ
            state = .needsProfileSetup
        }
    }

    /// M-02: プロフィール初期設定でusersレコードを新規作成
    func createProfile(userName: String, iconUrl: String?) async {
        do {
            let session = try await client.auth.session
            struct NewUser: Encodable {
                let id: UUID
                let user_name: String
                let icon_url: String?
            }
            try await client
                .from("users")
                .insert(NewUser(id: session.user.id, user_name: userName, icon_url: iconUrl))
                .execute()
            await loadProfile(userId: session.user.id)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// M-03: プロフィール表示・編集
    func updateProfile(userName: String, iconUrl: String?) async {
        do {
            let session = try await client.auth.session
            struct UpdateUser: Encodable {
                let user_name: String
                let icon_url: String?
            }
            try await client
                .from("users")
                .update(UpdateUser(user_name: userName, icon_url: iconUrl))
                .eq("id", value: session.user.id)
                .execute()
            await loadProfile(userId: session.user.id)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
        state = .signedOut
    }
}
