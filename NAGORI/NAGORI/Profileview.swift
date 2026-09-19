//
//  ProfileView.swift
//  NAGORI
//
//  M-03: プロフィール表示・編集（マイページ）
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var isEditing = false

    var body: some View {
        VStack(spacing: 16) {
            avatar
                .padding(.top, 24)

            Text(auth.currentProfile?.userName ?? "名前未設定")
                .font(.title2.bold())

            Button("プロフィールを編集") {
                isEditing = true
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 48)
            .buttonStyle(.plain)

            Spacer()
        }
        .navigationTitle("マイページ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("ログアウト", role: .destructive) {
                    Task { await auth.signOut() }
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            ProfileEditView()
        }
    }

    // MARK: - アイコン表示

    @ViewBuilder
    private var avatar: some View {
        if let urlString = auth.currentProfile?.iconUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholderAvatar
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
        } else {
            placeholderAvatar
                .frame(width: 120, height: 120)
        }
    }

    private var placeholderAvatar: some View {
        ZStack {
            Circle().fill(Color.pink)
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AuthManager.shared)
    }
}
