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
# Command Line Tools 環境では Testing.framework のパスを明示する必要がある
TESTING_FW_PATH := /Library/Developer/CommandLineTools/Library/Developer/Frameworks
test:
	swift test \
		-Xswiftc -F -Xswiftc $(TESTING_FW_PATH) \
		-Xlinker -rpath -Xlinker $(TESTING_FW_PATH)

# アプリバンドル作成
bundle:
	bash scripts/build.sh

# アプリバンドル作成 + 実行
bundle-run: bundle
	open .build/release/MagicSwitch.app
