---
name: verify
description: MagicSwitchのビルド・テスト・バンドル・起動を一連で動作確認する。「動作確認」「verify」「検証」「ビルド確認」などの依頼時に使用。
allowed-tools: Bash(make:*), Bash(swift:*), Bash(pgrep:*), Bash(pkill:*), Bash(open:*), Bash(ls:*), Bash(test:*), Bash(codesign:*), Bash(plutil:*), Bash(screencapture:*), Bash(sleep:*), Bash(defaults:*), Bash(wc:*), Bash(rm:*), Read
user-invocable: true
---

# MagicSwitch 動作確認 (`/verify`)

MagicSwitch のビルド・テスト・バンドル・起動を一連で検証する。
各ステップの結果を `[PASS]` / `[FAIL]` / `[SKIP]` で報告し、最後にサマリーを出力する。

## 使用方法

```
/verify              — フルパイプライン実行
/verify --skip-launch — ビルド検証のみ（アプリ起動しない）
/verify --clean       — クリーンビルドから開始
```

## 引数: $ARGUMENTS

- 引数なし → フルパイプライン実行
- `--skip-launch` → ビルド検証のみ（アプリ起動・スクリーンショット・クリーンアップをスキップ）
- `--clean` → クリーンビルドから開始

## 実行手順

以下の 11 ステップを順に実行せよ。各ステップの結果を記録し、最後にサマリーテーブルを出力する。

**重要な安全ルール:**
- 起動前に既存の MagicSwitch プロセスの PID を `pgrep -x MagicSwitch` で記録しておき、Step 11 のクリーンアップではそれらを殺さない（新規起動分のみ終了する）
- クラッシュログは起動前後の差分で新規分のみ検出する
- ステップが失敗しても原則パイプラインを中断せず続行する。ただし **Step 2 (Compile) が FAIL → Step 4, 5, 6, 7, 8, 9, 10, 11 は SKIP**、**Step 4 (Bundle) が FAIL → Step 5, 6, 7, 8, 9, 10, 11 は SKIP** とする
- `--skip-launch` 指定時は Step 7, 8, 9, 10, 11 を SKIP とする

---

### Step 1: Clean

- `--clean` が指定されている場合のみ `make clean` を実行する
- 指定がなければ SKIP

### Step 2: Compile

- `make build` を実行する
- exit code 0 → PASS、それ以外 → FAIL

### Step 3: Unit Tests

- `make test` を実行する
- Step 2 の結果に関係なく実行する（テストは独立）
- exit code 0 → PASS、それ以外 → FAIL

### Step 4: Bundle Build

- Step 2 が FAIL なら SKIP
- `make bundle` を実行する
- exit code 0 かつ `.build/release/MagicSwitch.app` が存在する → PASS、それ以外 → FAIL

### Step 5: Bundle Structure

- Step 4 が FAIL または SKIP なら SKIP
- 以下をすべて検証する:
  1. `.build/release/MagicSwitch.app/Contents/Info.plist` が存在する
  2. `.build/release/MagicSwitch.app/Contents/MacOS/MagicSwitch` が存在し実行可能である
  3. Info.plist に `CFBundleIdentifier`, `CFBundleName`, `CFBundleVersion`, `LSUIElement` キーが含まれる（`plutil -p` で確認）
- すべて OK → PASS、いずれか NG → FAIL（何が NG かを報告）

### Step 6: Code Signature

- Step 4 が FAIL または SKIP なら SKIP
- `codesign --verify --deep --strict .build/release/MagicSwitch.app` を実行する
- exit code 0 → PASS、それ以外 → FAIL（署名されていないケースも FAIL として報告するが、パイプラインは続行）

### Step 7: App Launch

- Step 4 が FAIL/SKIP、または `--skip-launch` 指定時は SKIP
- 起動前に `pgrep -x MagicSwitch` で既存 PID を記録する
- `open .build/release/MagicSwitch.app` を実行する
- 3 秒待機後、`pgrep -x MagicSwitch` で新しい PID が存在するか確認する
- 新しいプロセスが存在する → PASS、存在しない → FAIL

### Step 8: Crash Log Check

- Step 7 が FAIL/SKIP なら SKIP
- 起動前に `~/Library/Logs/DiagnosticReports/` 内の MagicSwitch 関連ファイル一覧を記録しておく（Step 7 の前に実行）
- 起動後に同ディレクトリを再チェックし、新規のクラッシュログがないか差分確認する
- 新規クラッシュログなし → PASS、あり → FAIL（ファイル名を報告）

### Step 9: App Data Directory

- Step 7 が FAIL/SKIP なら SKIP
- `~/Library/Application Support/MagicSwitch/` ディレクトリが存在するか確認する
- 存在する → PASS、存在しない → FAIL

### Step 10: Screenshot

- Step 7 が FAIL/SKIP なら SKIP
- `screencapture -x /tmp/magicswitch-verify-menubar.png` でスクリーンショットを取得する
- 撮影成功したら Read ツールで画像を表示し、メニューバーに MagicSwitch アイコンが見えるか視覚確認する
- アイコンが確認できる → PASS、確認できない → FAIL

### Step 11: Cleanup

- Step 7 が FAIL/SKIP なら SKIP
- Step 7 で記録した「新規起動した PID」のみを `pkill` で終了する（既存 PID は殺さない）
- `/tmp/magicswitch-verify-menubar.png` を削除する
- 正常終了 → PASS

---

## 出力フォーマット

全ステップ完了後、以下の形式でサマリーテーブルを出力せよ:

```
═══════════════════════════════════════════
  MagicSwitch Verification Results
═══════════════════════════════════════════
  Step 1  Clean              SKIP
  Step 2  Compile            PASS
  Step 3  Unit Tests         PASS
  Step 4  Bundle Build       PASS
  Step 5  Bundle Structure   PASS
  Step 6  Code Signature     PASS
  Step 7  App Launch         PASS
  Step 8  Crash Log Check    PASS
  Step 9  App Data Dir       PASS
  Step 10 Screenshot         PASS
  Step 11 Cleanup            PASS
═══════════════════════════════════════════
  Result: X/Y passed, Z skipped
═══════════════════════════════════════════
```

FAIL があった場合は、サマリーの後に失敗ステップの詳細を出力する。
