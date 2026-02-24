.PHONY: build clean run test bundle

# デフォルトターゲット
all: build

# デバッグビルド
build:
	swift build

# リリースビルド
release:
	swift build -c release

# クリーン
clean:
	swift package clean
	rm -rf .build/release/MagicSwitch.app

# 実行（デバッグ）
run: build
	.build/debug/MagicSwitch

# テスト実行
test:
	swift test

# アプリバンドル作成
bundle:
	bash scripts/build.sh

# アプリバンドル作成 + 実行
bundle-run: bundle
	open .build/release/MagicSwitch.app
