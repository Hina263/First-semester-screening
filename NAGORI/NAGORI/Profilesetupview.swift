//
//  M-02: プロフィール初期設定（初回ログイン時のみ）
//

import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var userName: String = ""
    @State private var isSaving = false

    private var canSubmit: Bool {
        !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("プロフィール初期設定")
                .font(.title2.bold())
            Text("表示名を入力してはじめましょう")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("ユーザー名（必須）", text: $userName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 32)

            if case .failed(let message) = auth.state {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task {
                    isSaving = true
                    await auth.createProfile(userName: userName, iconUrl: nil)
                    isSaving = false
                }
            } label: {
                Text(isSaving ? "保存中..." : "はじめる")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmit)
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}
