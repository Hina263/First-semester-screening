# First-semester-screening
# ① 最新のmainを取得
git checkout main
git pull origin main

# ② 作業ブランチを作成
git checkout -b feature/作業名

# ③ 作業する

# ④ 変更をステージング
git add .

# ⑤ コミット
git commit -m "feat: 変更内容"

# ⑥ GitHubへアップロード
git push -u origin feature/作業名

# ⑦ GitHubでPRを作成
# → レビュー・Approve
# → Merge
