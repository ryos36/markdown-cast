# Marp から動画を作る

Marp の `deck.md`（発話ノート付き）から字幕・音声つき最終動画までの手順。

---

## 前提条件まとめ

| カテゴリ | 必要なもの | 用途 |
|----------|-----------|------|
| **ランタイム** | Roswell (`ros`) | Common Lisp スクリプト群 |
| **ランタイム** | Node.js + `npx` | Marp CLI |
| **形態素解析** | `mecab` + 辞書（jumandic/ipadic） | 日本語テキスト解析 |
| **動画エンコード** | `gst-launch-1.0` | PNG から MP4（字幕焼き込み） |
| | `gstreamer1.0-plugins-base` | pngdec / videoconvert / videobox / textoverlay |
| | `gstreamer1.0-plugins-good` | mp4mux |
| | `gstreamer1.0-plugins-ugly` | x264enc |
| **フォント** | `fonts-noto-cjk`（Noto Sans CJK JP） | textoverlay の字幕描画 |
| **音声処理** | `sox` | wav 実測・tempo 変換 |
| **音声合成** | Azure Speech サブスクリプション | ★課金。ステップ 5b のみ |
| **動画合成** | `ffmpeg` | adelay + amix による音声配置 |
| **Lisp ライブラリ** | `adopt`（QuickLisp） | 全スクリプトの引数解析 |
| | `dexador` + `babel` | tts2wav の Azure HTTP 通信 |

> **Azure なしでできるステップ**: 1〜4、5a、6（dry-run）、8 はすべて Azure 不要。  
> `tts2wav --dry-run` を使うと実際の wav なしでタイミング計算を試せる。

---

## ディレクトリ構成

```
_build/
  note.ss             # ステップ 1 の出力
  bunsetu.ss          # ステップ 2 の出力
  caption.ss          # ステップ 3a の出力
  subs.srt            # ステップ 3b の出力（with-caption 用）
  tts.ss              # ステップ 5a の出力
  wavlist.ss          # ステップ 6 の出力
  final-pnglist.txt   # ステップ 8a の出力
  final-subs.srt      # ステップ 8c の出力
  orig-png/           # ステップ 4a の出力（Marp 生成）
  new-png/            # ステップ 4c の出力（ハードリンク）
  orig-wav/           # ステップ 5b の出力（Azure TTS キャッシュ）
  final-png/          # ステップ 8b の出力（通し番号で並べ直し）
  final-wav/          # ステップ 8e 中間（tempo 変換後 wav）
  with-caption.mp4        # ステップ 4d の出力（音声なし）
  final-caption.mp4       # ステップ 8d の出力（音声なし）
  final-caption-audio.mp4 # ステップ 8e の出力（最終動画）
```

---

## ステップ 1: 発話ノートを取り出す

**条件**: `awk`（標準 Unix）

```sh
awk -f bin/note2ss.awk deck.md > _build/note.ss
```

Marp の `<!-- ノート -->` コメントを S 式リストにする。  
ノートのないスライドは空リストになる。

---

## ステップ 2: テキスト解析（形態素解析・文節化）

**条件**: `ros`、`mecab` + 辞書（jumandic または ipadic）

```sh
ros bin/mapcar.ros \
    --strip-punctuation \
    bin/note2word.ros \
    bin/word2word.ros \
    bin/word2bunsetu.ros \
    -i _build/note.ss \
    -o _build/bunsetu.ss
```

| フィルタ | 処理 |
|----------|------|
| `note2word.ros` | mecab で `((単語 . 品詞) ...)` |
| `word2word.ros` | 複合語辞書で 1 語に畳む |
| `word2bunsetu.ros` | 助詞・副詞・句読点で文節に区切る |

`--strip-punctuation` を付けると句読点（。、）を文節テキストから落とす（字幕・音声の両方に効く）。  
省略すると句読点を残す。カスタム辞書を使う場合は `--dic dict.ss --no-white-list` を追加する。

---

## ステップ 3a: 字幕を作る

**条件**: `ros`

```sh
ros bin/bunsetu2caption.ros \
    --max-chars 10 \
    -i _build/bunsetu.ss \
    -o _build/caption.ss

ros bin/caption2srt.ros \
    --ms 800 \
    -i _build/caption.ss \
    -o _build/subs.srt
```

`--max-chars 10` で 1 caption の最大文字数を指定する。  
`--ms 800` は 1 caption の表示長（ms）。capms と一致させること。

---

## ステップ 4a: スライド PNG を生成する

**条件**: `npx`（Node.js 必須）、初回はネットワーク接続が必要（marp-cli ダウンロード）

```sh
mkdir -p _build/orig-png
npx --yes @marp-team/marp-cli@latest deck.md \
    --images png \
    --allow-local-files \
    -o _build/orig-png/slide.png
```

`slide.001.png`、`slide.002.png` … と連番で生成される。

---

## ステップ 4b: キャプション用 PNG リストを作る

**条件**: `ros`

```sh
ros bin/caption2pnglist.ros \
    -i _build/caption.ss \
    '_build/orig-png/slide.{%03i}.png' \
    '_build/new-png/frame.{%03j}.png' \
    > _build/pnglist.txt
```

`{%03i}` = スライド番号、`{%03j}` = caption 通し番号。

---

## ステップ 4c: ハードリンクで PNG を並べる

**条件**: 標準 Unix（`ln`、`xargs`）

```sh
mkdir -p _build/new-png
xargs -n 2 ln -f < _build/pnglist.txt
```

---

## ステップ 4d: 字幕焼き込み動画を作る

**条件**: `gst-launch-1.0`、以下のプラグインとフォント

| プラグイン | パッケージ |
|-----------|-----------|
| pngdec | `gstreamer1.0-plugins-good` |
| videoconvert / videobox / textoverlay | `gstreamer1.0-plugins-base` |
| x264enc | `gstreamer1.0-plugins-ugly` |
| mp4mux | `gstreamer1.0-plugins-good` |
| フォント | `fonts-noto-cjk`（Noto Sans CJK JP） |

```sh
gst-launch-1.0 \
  multifilesrc location="_build/new-png/frame.%03d.png" index=1 \
    caps="image/png,framerate=1000/800" \
  ! pngdec ! videoconvert \
  ! videobox border-alpha=0 bottom=-180 \
  ! textoverlay name=t \
      font-desc="Noto Sans CJK JP 20" \
      valignment=bottom halignment=left line-alignment=left xpad=20 \
  ! videoconvert ! x264enc ! mp4mux \
  ! filesink location=_build/with-caption.mp4 \
  filesrc location=_build/subs.srt \
  ! subparse subtitle-encoding=UTF-8 ! t.
```

`framerate=1000/800` は capms=800ms の場合。変えた場合はここも合わせる。  
`videobox bottom=-180` でスライド下に字幕エリア（180px）を追加する。

---

## ステップ 5a: TTS の読み上げ単位を作る

**条件**: `ros`（Azure 不要）

```sh
ros bin/bunsetu2tts.ros \
    -i _build/bunsetu.ss \
    -o _build/tts.ss
```

---

## ステップ 5b: Azure TTS で wav を生成する

**条件**: `ros`、`dexador` + `babel`（QuickLisp）、**Azure Speech サブスクリプション**、ネットワーク接続

> **★ここだけ課金が発生する。** wav がキャッシュ（`orig-wav/` に存在）されていれば Azure を呼ばない。

```sh
mkdir -p _build/orig-wav
ros bin/tts2wav.ros \
    --key "$AZURE_KEY" \
    --region japaneast \
    --voice ja-JP-NanamiNeural \
    --break-ms 120 \
    --end-ms 0 \
    --name '_build/orig-wav/output.{%03i}.wav' \
    -i _build/tts.ss \
    -o _build/tts.ss
```

`--end-ms 0` は文末の SSML break をなくす設定。0 以外にすると  
tempo 変換時に末尾無音まで速まり、尺の計算がずれる。

実際の Azure 呼び出しなしで試す場合（タイミング計算のシミュレーション）:

```sh
ros bin/tts2wav.ros --dry-run --dry-run-ms 200 \
    -i _build/tts.ss -o _build/tts.ss
```

---

## ステップ 6: タイミングを計算する

**条件**: `ros`、`sox`（wav 実測に使用）

```sh
ros bin/tts2wavlist.ros \
    --capms 800 \
    --head-ms 50 \
    --tail-ms 10 \
    --threshold 1.3 \
    '_build/orig-wav/output.{%03i}.wav' \
    '_build/final-wav/output.{%03i}.wav' \
    -i _build/tts.ss \
    -o _build/wavlist.ss
```

wav が存在しない A 番号で処理を打ち切る。  
`--dry-run` で生成した tts.ss（実測値なし）を使う場合は、sox での実測がないため  
ms は `--dry-run-ms` の推定値が入っている。

| フィールド | 意味 |
|------------|------|
| `factor` | `ms / avail`（avail = B×capms − head − tail） |
| `n` | factor > threshold のとき追加するフレーム数 |
| `new-rate` | 追加後の実効速度（`ms / ((B+n)×capms)`） |
| `running` | 通し番号（n の累計ずれを反映） |

---

## ステップ 8a: final PNG リストを作る

**条件**: `ros`

```sh
ros bin/ss2finalpng.ros \
    -i _build/wavlist.ss \
    -c _build/caption.ss \
    '_build/new-png/frame.{%03i}.png' \
    '_build/final-png/frame.{%03i}.png' \
    > _build/final-pnglist.txt
```

n>0 の文の末尾フレームを n 枚複製し、後続フレームを cumsum だけずらす。

---

## ステップ 8b: final PNG をリンクする

**条件**: 標準 Unix

```sh
mkdir -p _build/final-png
xargs -n 2 ln -f < _build/final-pnglist.txt
```

---

## ステップ 8c: final 字幕を作る

**条件**: `ros`

```sh
ros bin/ss2finalsrt.ros \
    -i _build/wavlist.ss \
    --capms 800 \
    _build/caption.ss \
    -o _build/final-subs.srt
```

---

## ステップ 8d: final 字幕焼き込み動画を作る

**条件**: ステップ 4d と同じ（gstreamer + プラグイン + フォント）

```sh
gst-launch-1.0 \
  multifilesrc location="_build/final-png/frame.%03d.png" index=1 \
    caps="image/png,framerate=1000/800" \
  ! pngdec ! videoconvert \
  ! videobox border-alpha=0 bottom=-180 \
  ! textoverlay name=t \
      font-desc="Noto Sans CJK JP 20" \
      valignment=bottom halignment=left line-alignment=left xpad=20 \
  ! videoconvert ! x264enc ! mp4mux \
  ! filesink location=_build/final-caption.mp4 \
  filesrc location=_build/final-subs.srt \
  ! subparse subtitle-encoding=UTF-8 ! t.
```

---

## ステップ 8e: 音声つき最終動画を作る

**条件**: `ros`、`sox`（tempo 変換）、`ffmpeg`（adelay + amix）

```sh
VIDEO=_build/final-caption.mp4 \
OUT=_build/final-caption-audio.mp4 \
WAVLISTSS=_build/wavlist.ss \
HEAD_MS=50 \
FRAME_MS=800 \
sh bin/final_audio_mux.sh
```

各文を sox tempo で new-rate 倍速に変換し、  
ffmpeg adelay で `HEAD_MS + (running−1)×FRAME_MS` ms の位置に配置して amix で合成する。

---

## パラメータ早見表

| パラメータ | 既定値 | 説明 |
|-----------|--------|------|
| `capms` / `FRAME_MS` | 800 | 1 フレームの長さ（ms）。全ステップで一致させること |
| `head-ms` / `HEAD_MS` | 50 | 各文の頭の余白（ms） |
| `tail-ms` | 10 | 各文の末尾の余白（ms） |
| `threshold` | 1.3 | この倍速を超えるとフレームを追加 |
| `max-chars` | 10 | 1 caption の最大文字数 |
| `break-ms` | 120 | 文節間の SSML break（ms） |
| `end-ms` | 0 | 文末の SSML break（ms）。0 推奨 |
| `strip_opt` | `--strip-punctuation` | 句読点を落とすなら `--strip-punctuation`、残すなら空 |

`avail = B × capms − head-ms − tail-ms`（各文に使える実効時間）

---

## テスト

```sh
lit test/
```

`REQUIRES:` ディレクティブで環境に応じて自動スキップする。  
Azure なし・gstreamer なし環境でも残りのテストは実行できる。
