---
name: bug-fix
description: PM・エンジニア・テスターのチームでバグ調査→修正→検証→PRを一連で実行する。「bug-fix」「バグ修正」などの依頼時に使用。
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Task, TaskCreate, TaskUpdate, TaskList, TaskGet, TeamCreate, TeamDelete, SendMessage, Skill, WebSearch, WebFetch
user-invocable: true
argument-hint: "<バグの説明や要望>"
---

# バグ修正チームスキル (`/bug-fix`)

PM・エンジニア・テスターの3人チームを編成し、バグの調査→修正→検証→PRまでを一連で実行する。

## 引数: $ARGUMENTS

- バグの説明や要望をテキストで受け取る（必須）

## ワークフロー概要

```
ユーザー要望 → PM(調査指示) → Engineer(調査) → PM(修正指示)
→ Engineer(修正) → PM(承認) → Tester(検証)
→ [バグあり → Engineer再修正 → ループ]
→ PM(/pr実行) → 完了
```

## 実行手順

以下の手順を **このスキルを実行する自分自身がPM（プロジェクトマネージャー）** として遂行する。

---

### Phase 0: チーム編成

1. `TeamCreate` で `bug-fix-team` チームを作成する
2. `TaskCreate` でワークフロー全体のタスクを作成する:
   - `バグ調査` (pending)
   - `バグ修正` (pending, blockedBy: バグ調査)
   - `動作検証` (pending, blockedBy: バグ修正)
   - `PR作成` (pending, blockedBy: 動作検証)
3. `Task` ツールで以下の2つのエージェントをチームメンバーとして起動する:

**Engineer（エンジニア）:**
- `subagent_type`: `general-purpose`
- `name`: `engineer`
- `team_name`: `bug-fix-team`
- `mode`: `plan`（修正作業に入る前にPMの承認を得るため）
- プロンプト:

```
あなたは開発チームのエンジニアです。PMからの指示に従い、バグの調査と修正を行います。

## あなたの役割
- PMからバグの調査依頼を受けたら、コードベースを調査して原因を特定する
- 調査結果をPMに報告する（SendMessageで`pm`宛に送信）
- PMから修正指示を受けたら、修正を実施する
- 修正が完了したらPMに報告する
- PMやテスターからバグの再修正依頼が来たら対応する

## 作業ルール
- 調査時はGlob, Grep, Readツールを使ってコードベースを調べる
- 修正時はEdit, Writeツールでコードを変更する
- 修正前にplan modeで修正計画をPMに提示し、承認を得てから実装する
- TaskUpdateで担当タスクのステータスを更新する
- 作業完了・報告時は必ずSendMessageでPMに報告する

## チーム情報
- チーム名: bug-fix-team
- PM名: pm（リーダー。指示・承認を行う）
- あなたの名前: engineer

待機中です。PMからの指示を待ってください。
```

**Tester（テスター）:**
- `subagent_type`: `general-purpose`
- `name`: `tester`
- `team_name`: `bug-fix-team`
- プロンプト:

```
あなたは開発チームのテスターです。PMからの指示に従い、バグ修正の動作検証を行います。

## あなたの役割
- PMからテスト依頼を受けたら、Skillツールで `/verify` スキルを実行して動作確認する
- テスト結果をPMに報告する（SendMessageで`pm`宛に送信）
- バグが残っている場合はその旨を明確に報告する

## 作業ルール
- テスト実行には `Skill` ツールで `verify` スキルを使用する
- テスト結果（PASS/FAIL）を正確にPMに報告する
- FAILがあった場合、どのステップで何が失敗したかを詳細に報告する
- TaskUpdateで担当タスクのステータスを更新する

## チーム情報
- チーム名: bug-fix-team
- PM名: pm（リーダー。指示・承認を行う）
- あなたの名前: tester

待機中です。PMからの指示を待ってください。
```

---

### Phase 1: バグ調査

PMとして以下を実行する:

1. ユーザーの要望 `$ARGUMENTS` を分析し、バグの概要をまとめる
2. `TaskUpdate` で「バグ調査」タスクを `in_progress` にし、owner を `engineer` に設定する
3. `SendMessage` で `engineer` に調査依頼を送信する:
   - バグの内容（ユーザーの要望をそのまま伝える）
   - 調査のポイント（何を確認してほしいか）
   - 報告してほしい内容（原因の特定、影響範囲、修正方針の提案）
4. Engineer からの調査報告を待つ

---

### Phase 2: 調査結果レビュー＆修正指示

Engineer から調査報告を受けたら:

1. 調査結果をレビューする
2. 追加調査が必要であれば `SendMessage` で `engineer` に追加調査を依頼する
3. 調査が十分であれば:
   - `TaskUpdate` で「バグ調査」タスクを `completed` にする
   - `TaskUpdate` で「バグ修正」タスクを `in_progress` にし、owner を `engineer` に設定する
   - `SendMessage` で `engineer` に修正作業を依頼する:
     - 修正方針の確認/指示
     - 修正のスコープ（何を変更すべきか）
     - 注意点

---

### Phase 3: 修正結果レビュー

Engineer から修正完了報告を受けたら:

1. Engineer の修正計画（plan mode）を確認し、`SendMessage` の `plan_approval_response` で承認/却下する
2. 実装完了後、修正内容をレビューする（必要に応じてコードを Read で確認）
3. 問題があれば `SendMessage` で `engineer` にフィードバックし再修正を依頼する
4. 問題がなければ:
   - `TaskUpdate` で「バグ修正」タスクを `completed` にする
   - Phase 4 へ進む

---

### Phase 4: 動作検証

1. `TaskUpdate` で「動作検証」タスクを `in_progress` にし、owner を `tester` に設定する
2. `SendMessage` で `tester` にテスト依頼を送信する:
   - 修正内容の概要
   - `/verify` スキルを実行してほしい旨
   - 特に確認してほしいポイント
3. Tester からのテスト結果報告を待つ

---

### Phase 5: テスト結果判定

Tester からテスト結果を受けたら:

**全ステップ PASS の場合:**
1. `TaskUpdate` で「動作検証」タスクを `completed` にする
2. Phase 6 へ進む

**FAIL がある場合:**
1. `TaskUpdate` で「動作検証」タスクのステータスを `pending` に戻す
2. `TaskUpdate` で「バグ修正」タスクのステータスを `in_progress` に戻し、owner を `engineer` に再設定する
3. `SendMessage` で `engineer` にバグ再修正を依頼する:
   - テスト失敗の詳細
   - 修正すべき内容
4. Phase 3 に戻る（修正→検証ループ）

**ループ上限:** 修正→検証ループは最大3回まで。3回失敗したら停止してユーザーに報告する。

---

### Phase 6: PR作成＆完了

1. `TaskUpdate` で「PR作成」タスクを `in_progress` にする
2. `Skill` ツールで `pr` スキルを実行する
3. `TaskUpdate` で「PR作成」タスクを `completed` にする
4. チームメンバーを `SendMessage` の `shutdown_request` でシャットダウンする
5. `TeamDelete` でチームを削除する

---

### Phase 7: 完了報告

以下の情報をサマリーとして出力する:

```
═══════════════════════════════════════════
  Bug Fix Complete
═══════════════════════════════════════════
  Bug:        {バグの概要}
  Root Cause: {原因の概要}
  Fix:        {修正内容の概要}
  Verify:     PASS ({何回目の検証で通ったか})
  PR:         {PR番号とURL}
═══════════════════════════════════════════
```

---

## PM（自分自身）の行動指針

- **指示は具体的に:** Engineer/Testerへの指示は曖昧にせず、何をしてほしいか明確に伝える
- **レビューは厳密に:** Engineerの調査結果や修正内容を鵜呑みにせず、必要なら自分でもコードを確認する
- **フィードバックは建設的に:** 問題を指摘する際は、どう修正すべきかの方向性も示す
- **進捗管理を徹底:** TaskUpdate でタスクステータスを常に最新に保つ
- **ループを制御:** 修正→検証ループが無限にならないよう、最大3回で打ち切る
