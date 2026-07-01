# markdown-cast

Marp の Markdown スライドを起点に、**字幕（SRT）・字幕焼き込み動画・ナレーション音声つき動画**を作るパイプライン。
スライドに埋め込んだ発話ノート（原稿）を、形態素解析・文節化を経て字幕 / TTS 音声に変換し、
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
| `_build/<deck>.pdf` | Marp の PDF |
| `_build/orig-png/*.png` | 1 スライド 1 枚の PNG |
| `_build/subs.srt` | 字幕 SRT |
| `_build/<deck>.mp4` | 字幕を焼き込んだ動画（音声なし） |
| `_build/<deck>-audio.mp4` | 字幕＋ナレーション音声つき動画（最終成果物） |

`ninja video`（音声なし動画）と `ninja pdf` は Azure 不要。  
`ninja video-audio`（音声つき動画）は Azure TTS が必要。ただし後述のガードで課金をコントロールできる。

---

## 必要なもの

`ros`（Roswell）/ `mecab` / `gst-launch-1.0` / `ffmpeg` / `sox` / `npx`（Marp CLI）。  
TTS には Azure Speech のキーが必要（`key.ninja` の `key` 変数。コミットしないこと）。  
詳細な前提条件とバージョン・パッケージ名は [marp-to-movie.md](marp-to-movie.md) を参照。

---

## 主なターゲット

```
ninja                 # デフォルト: video + video-audio + pdf をすべて作る
ninja video           # 字幕つき動画（音声なし、Azure 不要）
ninja pdf             # PDF（Azure 不要）
ninja video-audio     # 音声つき最終動画（Azure 必要 / --dry-run 可）
ninja wav             # TTS wav のみ生成
ninja png             # スライド PNG のみ
ninja srt             # 字幕 SRT のみ
```

`build.ninja` 冒頭の変数：`capms`（1 フレーム長）, `head_ms`/`tail_ms`（前後余白）,
`break_ms`/`end_ms`（文節間・文末の間）, `threshold`（速すぎ防止の閾値）など。

---

## Azure 課金のガード

音声化（`ninja video-audio` の TTS ステップ）は Azure を呼ぶたびに課金される。
`tts2wav.ros` には以下のガードが組み込まれている。

### 1. `--dry-run`（デフォルト設定）

Azure を呼ばず、再生時間を「文節数 × 固定値（既定 200 ms）」で見積もる。wav は作らない。  
`key.ninja` の初期値は `tts_opt = --dry-run` なので、キーを設定せずにパイプライン全体の流れを確認できる。  
文言を調整したり構成を試したりするときに使う。音声タイミングの精度は下がるが Azure は呼ばない。

### 2. キャッシュ（同じ内容なら再生成しない）

同じテキスト・設定で生成済みの wav があれば Azure を呼ばず再利用する。  
メタデータは `_build/orig-wav/tts-info.ss` で管理する。テキストや設定が変わった wav だけ再生成し、旧 wav は `_build/backup-wav/` へ自動退避する。

### 3. `limit`（既定 6）

最初の N ページだけ音声化して止まる。最初の数ページだけ先に音声を確認したいときに使う。  
`key.ninja` の `limit = 6` で設定する。全ページ音声化するときは `limit = 0` にする。

なお `--dry-run` のまま（wav が 0 本）でも `video-audio` は作られる。音声の代わりにプリセット音（440Hz 0.3 秒）が先頭に一度鳴るだけで、実質ほぼ無音の動画になる。

### 4. 途中まで書いた `tts.ss`

`tts.ss` にエントリが書いてある分だけ処理される。スライドのノートを書き進めながら、できた分から順に音声化できる。後から追記しても既存 wav はキャッシュで再利用される。

### 5. `--bootstrap`

既存の wav を `tts-info.ss` に再登録する。wav はあるが info が欠けているとき（別環境から持ってきた場合など）に使う。Azure は呼ばない。

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
| `final_audio_mux.sh` | ffmpeg | wav を時刻配置して動画に重ねる |

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

`init.sh` は環境チェックを行い、`deck.md` / `build.ninja` / `key.ninja` / 辞書テンプレートを生成する。

```sh
# 3. deck.md を書く（発話ノートを <!-- --> で書く）
$EDITOR deck.md          # 単発の場合
$EDITOR slide0/deck.md   # サブディレクトリの場合

# 4. ninja でビルド
ninja video    # 字幕つき動画（Azure 不要）
ninja          # 全成果物（デフォルト: video + video-audio + pdf）
```

音声つき動画（`video-audio`）を作るには `key.ninja` の `key` に Azure Speech のキーを設定し、
`tts_opt = --dry-run` の行をコメントアウトすること（コミットしないこと）。

---

## ドキュメント

| ファイル | 内容 |
|---|---|
| [design.md](design.md) | 設計思想（文節=1フレームの時間軸、音声・字幕合わせの仕組み） |
| [pipeline.md](pipeline.md) | 処理順の概要（8ステップのデータフロー） |
| [marp-to-movie.md](marp-to-movie.md) | 各ステップの実行コマンドと前提条件の詳細 |
