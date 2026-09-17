//
//  M-01: メールアドレス＋パスワードでのログイン/新規登録
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUpMode = false
    @State private var isSubmitting = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case email, password
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
            && password.count >= 6
            && !isSubmitting
    }

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                titleSection

                Spacer(minLength: 32)

                modeToggle
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)

                formFields
                    .padding(.horizontal, 28)

                if case .failed(let message) = auth.state {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 10)
                }

                submitButton
                    .padding(.horizontal, 28)
                    .padding(.top, 20)

                Spacer(minLength: 24)

                Text("続けることで、利用規約およびプライバシーポリシーに同意したものとみなされます。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer(minLength: 24)
            }
        }
    }

    // MARK: - 背景

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.90, blue: 0.93),
                Color(red: 1.0, green: 0.97, blue: 0.97)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - タイトル

    private var titleSection: some View {
        VStack(spacing: 10) {
            Text("🌸")
                .font(.system(size: 40))
            Text("散り桜マップ")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("散りゆく桜の瞬間を、みんなで共有しよう")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - ログイン/新規登録の切り替え（自作カプセルトグル）

    private var modeToggle: some View {
        HStack(spacing: 0) {
            toggleButton(title: "ログイン", isSelected: !isSignUpMode) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSignUpMode = false
                }
            }
            toggleButton(title: "新規登録", isSelected: isSignUpMode) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSignUpMode = true
                }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.6))
        .clipShape(Capsule())
    }

    private func toggleButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.black : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 入力欄

    private var formFields: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                TextField("メールアドレス", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.8))
            .clipShape(Capsule())

            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                SecureField("パスワード（6文字以上）", text: $password)
                    .focused($focusedField, equals: .password)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.8))
            .clipShape(Capsule())
        }
    }

    // MARK: - 送信ボタン

    private var submitButton: some View {
        Button {
            focusedField = nil
            Task {
                isSubmitting = true
                if isSignUpMode {
                    await auth.signUp(email: email, password: password)
                } else {
                    await auth.signIn(email: email, password: password)
                }
                isSubmitting = false
            }
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(isSignUpMode ? "新規登録" : "ログイン")
                        .font(.headline)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canSubmit ? Color.black : Color.black.opacity(0.3))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager.shared)
}
