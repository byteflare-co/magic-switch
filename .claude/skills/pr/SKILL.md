---
name: pr
description: 未コミット変更をコミットし、PRを作成してmainにマージする。mainブランチならそのままpush。「PR作成」「pr」「マージ」などの依頼時に使用。
allowed-tools: Bash, Read, Edit, Glob, Grep
user-invocable: true
---

# PR統合スキル (`/pr`)

未コミット変更をコミットし、PR作成→mainマージを自動実行する。

## 引数: $ARGUMENTS

- 引数なし → デフォルト動作

## 実行手順

以下のステップを順に実行せよ。

---

### Step 1: 環境検出

1. `git worktree list` を実行し、最初のエントリからメインリポジトリルートを特定する
2. `git branch --show-current` で現在のブランチ名を取得する
3. 現在のブランチ名を `CURRENT_BRANCH`、メインリポジトリルートを `MAIN_REPO` として記録する

### Step 2: 未コミット変更のコミット＆プッシュ

1. `git status --porcelain` で変更を確認する
2. 変更がある場合:
   - `git add -A` でステージング
   - 変更内容を確認し、適切なコミットメッセージを生成してコミット
   - `git push origin $CURRENT_BRANCH` でプッシュ（上流未設定なら `-u` を付与）
3. 変更がない場合:
   - 未プッシュのコミットがあるか `git log origin/$CURRENT_BRANCH..HEAD` で確認
   - あれば `git push origin $CURRENT_BRANCH` でプッシュ

### Step 3: ブランチ統合

**`CURRENT_BRANCH` が `main` の場合:**
- Step 2 でプッシュ済みなので、このステップはスキップ
- 完了報告へ進む

**`CURRENT_BRANCH` が `main` 以外の場合:**

#### 3a: PR作成

1. `gh pr view --json number,title,url` で既存PRを確認
2. 既存PRがない場合:
   - `git log main..$CURRENT_BRANCH --oneline` でコミット一覧を取得
   - PRタイトルとbodyを生成（コミット内容を要約）
   - `gh pr create --base main --title "..." --body "..."` でPRを作成
3. 既存PRがある場合:
   - そのPRを使用する

#### 3b: PRマージ

**重要:** `gh pr merge --delete-branch` はマージ後にローカルで `git checkout main` を試みるため、ワークツリーから実行すると失敗する。そのため `--delete-branch` は使わず、リモートブランチ削除は別途行う。

1. `gh pr merge --squash` でマージを試みる
2. **成功した場合** → リモートブランチを削除: `git push origin --delete $CURRENT_BRANCH` → 3c へ進む
3. **失敗した場合（conflict）:**
   - `git fetch origin main` を実行
   - `git rebase origin/main` でリベースを試みる
   - conflictが発生したら、conflictを解消してリベースを完了する
   - `git push --force-with-lease` でプッシュ
   - `gh pr merge --squash` を再試行
   - 成功したら `git push origin --delete $CURRENT_BRANCH` でリモートブランチ削除
   - **2回目も失敗した場合は停止し、エラーを報告する**

#### 3c: メインリポジトリ同期＆ローカルブランチ削除

**ワークツリーから実行した場合:**
1. `MAIN_REPO` ディレクトリに移動する
2. `git pull origin main` でmainを最新化する
3. `git worktree remove <現在のワークツリーパス>` でワークツリーを削除する（ローカルブランチも自動削除される）

**通常のブランチから実行した場合（ワークツリーでない）:**
1. `git checkout main` でmainに切り替える
2. `git pull origin main` でmainを最新化する
3. `git branch -d $CURRENT_BRANCH` でローカルブランチを削除する

### Step 4: 完了報告

以下の情報をサマリーとして出力する:

- マージ元ブランチ名（mainの場合は「mainに直接プッシュ」）
- PR番号とURL（PRを作成/使用した場合）
- マージ方法（squash merge）
- コミット数
