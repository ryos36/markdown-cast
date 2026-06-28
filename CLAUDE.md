# CLAUDE.md — markdown-cast 引き継ぎメモ

## プロジェクトの状態（2026-06-28 時点）

Marp → 字幕・音声つき動画のパイプライン（8 ステップ）が全工程実装済み。  
lit テスト 31 件すべて PASS。

---

## やり残し・次にやること

### 最優先: 句読点除去（TODO.md に詳細あり）

`word2bunsetu` が句読点「。」「、」を文節末尾に付けたまま出力している。  
これが字幕（caption）と TTS の両方に流れている。

- 字幕からだけ除く → `bunsetu2caption.ros` に句読点ストリップを追加  
- TTS 側も除くかは、ms/factor への影響を before/after で確認してから判断  
- 区切り判定ロジックは壊さず、出力テキストからだけ除く

### ninja build.ninja の整備

現状は各ステップをバラバラに手で実行する形。  
`build.ninja` を書けば `ninja final-caption-audio.mp4` 一発で全工程を回せる。  
MicroBit の `build.ninja` が参考になる。

### README の整備

現状の `README.md` はパイプラインの仕組みの説明。  
GitHub 公開に向けて「インストール方法」「最小限の使い方」を追加する必要がある。

---

## 懸念点

### ss2wav.ros が未移植

`bin/` には `tts2wav.ros`（バッチ処理版）があるが、`ss2wav.ros`（1 文単位の単体実行版）は移植していない。  
MicroBit 側では `tts2wav.ros` が内部的に `ss2wav.ros` と同等の処理を持っているので  
現パイプラインは動くが、単体デバッグ用途に欲しい場合は移植が必要。

### テストが dry-run / stub ベース

`tts2wav` テストは `--dry-run` のみ。実 Azure を叩くテストはない。  
Azure のレスポンス変化（音声モデル更新など）はテストで検知できない。

### gstreamer の textoverlay がフォント依存

`fonts-noto-cjk`（Noto Sans CJK JP）がないと textoverlay が文字化けまたはクラッシュする。  
CI 環境に追加が必要。lit の `REQUIRES:` で制御していないので、フォントがない環境で  
`test/video/01-gstreamer-mp4.test` が静かに文字化けしたまま PASS する可能性がある。

### capms の一貫性

`capms=800` を `caption2srt`・`tts2wavlist`・`final_audio_mux`・gstreamer の `framerate` に  
それぞれ別々に渡している。どれか一つ変え忘れると動画と音声がずれる。  
`build.ninja` で変数化することで解決できる。

---

## ファイル構成メモ

```
bin/         パイプラインの全ツール（.ros = Common Lisp、.sh = シェル）
test/        lit テスト（ステップごとにサブディレクトリ）
pipeline.md  処理順の概要
marp-to-movie.md  各ステップの実行コマンドと前提条件の詳細
TODO.md      句読点除去の詳細検討
```

---

## テスト実行

```sh
lit test/
```

`REQUIRES:` で自動スキップするので、`npx` / `gst-launch-1.0` / `ffmpeg` / `sox` が  
インストール済みの環境ほど多くのテストが走る。Azure なしでも 29 件以上は通る。
