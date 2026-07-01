# TODO

## 句読点（。、）を字幕から削除する（最優先）

字幕の本文から句読点を消したい。

### 現状
`word2bunsetu` が句読点「。」「、」を捨てずに直前の文節にくっつけている。
この文節文字列が、**字幕（caption）にも TTS の読み上げテキストにも両方そのまま流れる**ので、
字幕に句読点が残る。

### 仮説
TTS で句読点のぶんだけ間が伸びている可能性。
Azure TTS にテキストとして「。」「、」を渡すと、SSML の `break_ms` とは別に、句読点自体の間が入り、
音声尺（`ms`）が伸びていそう。そうだとすると `factor` の計算（音声尺 ÷ 割当時間）にも効いている。

### 対応案 / 検証
- 字幕を作る段（caption 化）で句読点を落とす。音声側に句読点を残すか消すかは分けて考える。
  - 案 A: **字幕からだけ**消す（TTS にはそのまま）。見た目だけ変わる。間は今のまま。
  - 案 B: **TTS のテキストからも**消し、間は `break_ms`/`end_ms`（SSML）だけで作る。
    句読点ぶんの間が消え、音声尺が短くなる。タイミングがどう変わるか要確認。
- 句読点を消したときの `ms` / `factor` / フレーム数の変化を before/after で比べる。
- 文（読み上げ単位）の切れ目は句読点で決めているので、**区切り判定は今のまま残し、出力テキストからだけ
  句読点を除く**形にする（区切りロジックを壊さない）。

---

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

管理されたパイプライン（辞書を固定したい）を作るときはフラグを外して
whitelist ハッシュを管理する形に戻すとよい。

---

## key.ninja の dry-run 説明文が誤り

`key.ninja` のコメント「Azure を使わず wav の長さだけ見積もる dry-run モード」は誤った解釈。
正しい説明に直す。

---

## tts2wav テストが dry-run のみ

`tts2wav` テストは `--dry-run` のみで、実際の Azure 通信はテストしていない。  
Azure 側の音声モデル更新などは検知できない。現状は許容する（課金が発生するため）。
