//
//  FilterView.swift
//  NAGORI
//
//  M-08 マップの絞り込み（都道府県・投稿時期）担当: すみー
//

import SwiftUI

struct FilterView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedPrefecture: String
    @Binding var selectedPeriod: String

    // 都道府県リストはCreatePostViewのものを再利用（"すべて"だけ先頭に追加）
    private let prefectures = ["すべて"] + CreatePostView.prefectures

    private let periods = [
        "すべて",
        "7日以内",
        "8〜21日",
        "22〜45日",
        "46〜60日"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("都道府県") {
                    Picker("都道府県", selection: $selectedPrefecture) {
                        ForEach(prefectures, id: \.self) { prefecture in
                            Text(prefecture).tag(prefecture)
                        }
                    }
                }

                Section("投稿時期") {
                    Picker("投稿時期", selection: $selectedPeriod) {
                        ForEach(periods, id: \.self) { period in
                            Text(period).tag(period)
                        }
                    }
                }
            }
            .navigationTitle("検索・フィルタ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("リセット") {
                        selectedPrefecture = "すべて"
                        selectedPeriod = "すべて"
                    }
                }
            }
        }
    }
}

#Preview {
    FilterView(selectedPrefecture: .constant("すべて"), selectedPeriod: .constant("すべて"))
}
