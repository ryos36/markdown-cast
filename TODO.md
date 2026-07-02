# TODO

## gstreamer のフォント依存（テストの抜け）

`fonts-noto-cjk`（Noto Sans CJK JP）がないと textoverlay が文字化けまたはクラッシュする。  
`test/video/01-gstreamer-mp4.test` は `REQUIRES: gst-launch-1.0` のみで、フォントの有無を確認していない。  
フォントがない環境で文字化けしたまま PASS する可能性がある。

対応案: `lit.cfg.py` でフォントファイルの存在チェックを追加し、`fonts-noto-cjk` を feature 登録する。

---

## capms の一貫性

`capms=800` を複数箇所（`caption2srt`・`tts2wavlist`・`final_audio_mux`・gstreamer の `framerate`）に
個別に渡している。どれか一つ変え忘れると動画と音声がずれる。  
`build.ninja` で変数化することで解決できる。

---

## mapcar の whitelist の設計メモ

`mapcar.ros` の whitelist 照合は 2 つの対象を持つ:

- **フィルタ**（`filter-function`）— `--info` を `eval` する = 任意コード実行。
  ファイル削除・通信なども可能。whitelist は**本物のセキュリティ機構**。
- **辞書**（`load-dic-checked`）— `*read-eval* nil` で `read` する = データのみ。
  リスクはクラッシュ（循環リスト等）や予期しない変換程度。**データ完全性チェックに近い**。

この 2 つを分けて制御するため、オプションを 2 本用意してある:

| オプション | 効果 |
|---|---|
| `--no-white-list` | フィルタと辞書の両方を無効化 |
| `--no-dic-white-list` | 辞書の照合だけを無効化。フィルタ保護は残る |

**`share/rules.ninja` は `--no-dic-white-list` を使用**。
ユーザーが `mecab-private.dict.ss` を自由に編集できる一方、
フィルタ（note2word / word2word / word2bunsetu）の照合は維持される。

辞書を固定して管理したい場合はフラグを外して
whitelist ハッシュを管理する形に戻すとよい。

---

## key.ninja の dry-run 説明文が誤り

`key.ninja` のコメント「Azure を使わず wav の長さだけ見積もる dry-run モード」は誤った解釈。
正しい説明に直す。

---

## tts2wav テストが dry-run のみ

`tts2wav` テストは `--dry-run` のみで、実際の Azure 通信はテストしていない。  
Azure 側の音声モデル更新などは検知できない。現状は許容する（課金が発生するため）。

---

## サンプル動画を公開する

`examples/` の完成 mp4 をどこか（GitHub Releases 等）に置いて、
README や examples/README.md から再生できるようにする。

---

## ロゴ

`powered by markdown-cast` 用のロゴ画像を作る。
動画末尾やサンプル動画に入れられるようにする。

---

## 短いムービーの挿入機能

番組の合間に入るような短いムービー（アイキャッチ）を差し込む機能。
動画の冒頭・末尾・スライド間など、指定した位置に挿入できるとよい。

---

## 最後のロール + NG 集

動画の末尾にクレジットロールや NG 集を入れる機能。

---

## AI を使った簡易アニメーション

AI で生成した画像を使って簡易アニメーションを作る機能。
