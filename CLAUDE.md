# CLAUDE.md — markdown-cast

## プロジェクトの状態（2026-06-28 時点）

Marp → 字幕・音声つき動画のパイプライン（8 ステップ）が全工程実装済み。  
lit テスト 31 件すべて PASS。

## テスト実行

```sh
lit test/
```

`REQUIRES:` で自動スキップするので `npx` / `gst-launch-1.0` / `ffmpeg` / `sox` が  
インストール済みの環境ほど多くのテストが走る。Azure なしでも 29 件以上は通る。

## ファイル構成

```
bin/              パイプラインの全ツール（.ros = Common Lisp、.sh = シェル）
test/             lit テスト（ステップごとにサブディレクトリ）
pipeline.md       処理順の概要
marp-to-movie.md  各ステップの実行コマンドと前提条件の詳細
TODO.md           懸念点・積み残し課題
```

## 次にやること

優先順は TODO.md を参照。主な積み残し:

1. **句読点除去** — 字幕・TTS 側それぞれの対応方針を決めて実装（詳細は TODO.md）
2. **build.ninja の整備** — 現状は各ステップを手で実行する形。`ninja final-caption-audio.mp4` 一発で回せるようにする
3. **README の整備** — GitHub 公開向けにインストール方法と最小限の使い方を追加
