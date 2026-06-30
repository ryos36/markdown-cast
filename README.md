# markdown-cast

Marp の Markdown スライドを起点に、**字幕（SRT）・字幕焼き込み動画・ナレーション音声つき動画**を作るパイプライン。
スライドに埋め込んだ発話ノート（原稿）を、形態素解析 → 文節 → 字幕 / TTS 音声に変換し、
**音声の長さに合わせて字幕とフレームのタイミングを自動で調整する**のが中心の仕事。

ビルドは `ninja`、変換ツールは Common Lisp（Roswell / `ros`）と awk、
音声・動画は Azure TTS / `sox` / `ffmpeg` / `gstreamer` / Marp CLI を使う。

> このリポジトリは、別プロジェクト（子ども向けイベントの企画スライド動画化）で育てたパイプラインを切り出したもの。

---

## 何ができるか

入力は 1 枚の Marp Markdown（`deck.md`）。発話ノートを HTML コメント `<!-- ... -->` で各スライドに書いておく。
そこから次を作る。

| 出力 | 中身 |
|---|---|
| `deck.pdf` | Marp の PDF |
| スライド PNG | 1 スライド 1 枚 |
| `subs.srt` | 字幕 |
| `*-with-caption.mp4` | 字幕を焼き込んだ動画（音声なし） |
| `*-with-caption-audio.mp4` | 字幕＋ナレーション音声つき動画 |
| `*-final-caption-audio.mp4` | 速度調整でフレームを足し、通し番号を振り直した最終版 |

`ninja wav`（Azure TTS で課金）以外は Azure 不要。タイミング等は `build.ninja` 冒頭の変数で調整する。

---

## 必要なもの

`ros`（Roswell）/ `mecab` / `gst-launch-1.0` / `ffmpeg` / `sox` / `npx`（Marp CLI）。  
TTS には Azure Speech のキーが必要（`build.ninja` の `key` 変数。コミットしないこと）。  
詳細な前提条件とバージョン・パッケージ名は [marp-to-movie.md](marp-to-movie.md) を参照。

---

## 主なターゲット

```
ninja pdf                     # PDF
ninja png                     # スライド PNG
ninja srt                     # 字幕 SRT
ninja with-caption.mp4        # 字幕焼き込み動画
ninja wav                     # ★Azure TTS で各文を wav 化（課金注意）
ninja with-caption-audio.mp4  # 音声つき動画
ninja final-caption-audio.mp4 # 速度調整・通し番号振り直しの最終版
```

`build.ninja` 冒頭の変数：`capms`（1 フレーム長）, `head_ms`/`tail_ms`（前後余白）,
`break_ms`/`end_ms`（SSML の間）, `threshold`（速すぎ防止の閾値）など。

---

## ツール一覧

| ファイル | 種別 | 役割 |
|---|---|---|
| `note2ss.awk` | awk | 発話ノート（`<!-- -->`）を 1 個の S 式リストにする |
| `note2word.ros` | mecab | テキストを `((単語 . 品詞) …)` にする |
| `word2word.ros` | filter | 複合語辞書で mecab の分割を 1 語に畳む |
| `word2bunsetu.ros` | filter | 助詞・副詞・句読点で区切って文節にまとめる |
| `bunsetu2caption.ros` | filter | 文を字幕（caption）の列にする（N 文字で折り返し） |
| `mapcar.ros` | 単体 | S 式の各要素に filter チェーンを mapcar する汎用ツール |
| `caption2srt.ros` | 単体 | caption を平坦化して固定長の SRT にする |
| `caption2pnglist.ros` | 単体 | caption からフレーム複製の元/先名の対を作る |
| `bunsetu2tts.ros` | 単体 | 文節構造から「文ごと」の読み上げ単位を作る |
| `tts2wav.ros` | Azure | 各文を Azure TTS で wav 化（読み辞書・SSML・キャッシュ） |
| `tts2wavlist.ros` | 単体 | 音声の実測尺から factor / n / 通し番号を計算し `wavlist.ss` を作る |
| `ss2finalpng.ros` | 単体 | 通し番号でフレームを並べ直す（ハードリンク） |
| `ss2finalsrt.ros` | 単体 | 通し番号に合わせて SRT を再タイミング |
| `mux_audio.sh` / `final_audio_mux.sh` | ffmpeg | wav を時刻配置して動画に重ねる |

補助：`ss2wav.ros`（単発 TTS）, `sort.ros` / `uniq.ros` / `nth.ros` / `pretty.ros` / `parsenum.ros` 等。

---

## 始め方

markdown-cast を git submodule として親プロジェクトに組み込み、`bin/init.sh` で足場を生成する。

```sh
# 1. 親プロジェクトを作る
mkdir my-slides && cd my-slides
git init
git submodule add https://github.com/ryos36/markdown-cast

# 2. 足場を生成する
#    スライド1本だけのとき（カレントにファイルを置く）
sh markdown-cast/bin/init.sh

#    スライドを複数管理するとき（サブディレクトリ + 辞書を share/ に共通化）
sh markdown-cast/bin/init.sh slide0
sh markdown-cast/bin/init.sh slide1
```

`init.sh` は環境チェックを行い、`deck.md` / `build.ninja` / 辞書テンプレートを生成する。

```sh
# 3. deck.md を書く（発話ノートを <!-- --> で書く）
$EDITOR deck.md          # 単発の場合
$EDITOR slide0/deck.md   # サブディレクトリの場合

# 4. ninja でビルド
ninja with-caption.mp4        # 字幕つき動画（Azure 不要）
ninja final-caption-audio.mp4 # 音声つき最終動画（Azure 必要）
```

Azure TTS を使う場合は生成された `build.ninja` の `key` / `region` / `voice` を設定すること（コミットしないこと）。

---

## ドキュメント

| ファイル | 内容 |
|---|---|
| [design.md](design.md) | 設計思想（文節=1フレームの時間軸、音声・字幕合わせの仕組み） |
| [pipeline.md](pipeline.md) | 処理順の概要（8ステップのデータフロー） |
| [marp-to-movie.md](marp-to-movie.md) | 各ステップの実行コマンドと前提条件の詳細 |
