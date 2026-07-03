# CLAUDE.md — markdown-cast

## プロジェクトの状態（2026-07-03 時点）

Marp から字幕・音声つき動画を作る 8 ステップの全工程実装済み。  
ninja によるビルドも整備済み（`share/rules.ninja` を各 deck の `build.ninja` から include し、
`ninja video-audio` で最終成果物まで一発で作れる）。  
README / tutorial.md / install.md も公開向けに整備済み。  
lit テスト 37 件すべて PASS。

## テスト実行

```sh
lit test/
```

`REQUIRES:` で自動スキップするので `npx` / `gst-launch-1.0` / `ffmpeg` / `sox` が  
インストール済みの環境ほど多くのテストが走る。Azure なしでも 29 件以上は通る。

## ファイル構成

```
bin/              全ツール（.ros = Common Lisp、.sh = シェル）
test/             lit テスト（ステップごとにサブディレクトリ）
share/            共通の ninja ルール（rules.ninja）・辞書・素材
templates/        新規 deck の雛形（build.ninja.in、key.ninja 等）
examples/         サンプル deck（intro、rawls-san）
podman/ podman.md コンテナ化の作業ディレクトリと計画
pipeline.md       処理順の概要
marp-to-movie.md  各ステップの実行コマンドと前提条件の詳細
TODO.md           懸念点・積み残し課題
```

## 用語ルール

- 「パイプライン」という言葉は `pipeline.md` 以外のファイルでは使わない。
  他の md・ソース・コメントでは「処理の流れ」「ビルド手順」「各ステップ」などで言い換える。

## 可否質問と plan の出し方

- 「できますか？」にはまず「できる／できない」だけ答える。理由は書かない。
- 可否を答えた後、plan を求められてから作る。いきなり plan を出さない。
- plan に「なぜやるか（理由・背景）」は書かない。
- plan は「やることのトップリスト＋注意事項」だけのサマリーにする。詳細は折りたたむ（必要なときだけ展開）。

## 次にやること

優先順は TODO.md を参照。主な積み残し:

1. **gstreamer のフォント依存チェック** — `lit.cfg.py` に `fonts-noto-cjk` の feature 登録を追加
2. **Podman コンテナ化の続き** — `$run` ラッパ変数の導入から再開（podman.md 参照）
3. **サンプル動画の公開** — examples/ の完成 mp4 を GitHub Releases 等に置く
