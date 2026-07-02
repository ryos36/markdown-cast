# markdown-cast  Ver 1.00

Marp のスライドから、字幕・音声つき動画を作るツールです。

音声合成には Microsoft Azure TTS を使います。

---

## 何ができるか

入力は Marp 形式の Markdown ファイル（`deck.md`）1 枚。
発話ノートを HTML コメント `<!-- ... -->` で各スライドに書いておくと、
次の 2 種類の動画を作れます。

- **字幕つき動画** — Azure TTS なしで作れます
- **音声つき動画** — Azure TTS を使います

まず字幕つき動画で内容を確認し、準備ができたら音声つき動画を作る流れが基本です。

---

## 始め方

### 1. 作業ディレクトリを用意する

スライドや音声ファイルを置くディレクトリを作り、
markdown-cast を git submodule として追加します。

```sh
mkdir my-slides && cd my-slides
git init
git submodule add https://github.com/ryos36/markdown-cast
```

git を使わない場合は、GitHub からダウンロードしたファイルを `markdown-cast/` に置いても動きます。

### 2. 必要なファイルを生成する

```sh
sh markdown-cast/bin/init.sh my-first-slide
```

引数にディレクトリ名を渡します。このディレクトリ名が出力ファイル名になります。

```
my-first-slide  →  _build/my-first-slide.mp4
```

実行すると `my-first-slide/deck.md`・`my-first-slide/build.ninja`・`my-first-slide/key.ninja` と
辞書テンプレート（`share/mecab-private.dict.ss` / `share/pronunciation.dict.ss`）が作られます。

ディレクトリ名がそのまま出力ファイル名になるので、スライドの内容に合った名前をつけます。

```
my-slides/
├── markdown-cast/       (submodule)
├── share/
│   ├── mecab-private.dict.ss
│   └── pronunciation.dict.ss
└── my-first-slide/
    ├── build.ninja
    ├── deck.md
    └── key.ninja
```

### 3. スライドと発話ノートを書く

`my-first-slide/deck.md` を編集します。
スライドの内容と、`<!-- -->` の中に話す内容（発話ノート）を書きます。

```markdown
## スライドタイトル

スライドの内容

<!-- ここに話す内容 -->
```

発話ノートに書いた内容が、動画の字幕になります（Azure TTS を使えば音声にもなります）。

### 4. 動画を作る

```sh
cd my-first-slide
ninja video    # 字幕つき動画（Azure 不要）
```

`_build/my-first-slide.mp4` に字幕つきの動画ができます。

### 5. 動画を再生する

```sh
ffplay _build/my-first-slide.mp4    # Linux
open   _build/my-first-slide.mp4    # Mac
```

---

## サンプルを試す

`examples/` に動かせるサンプルがあります。

```sh
cd examples/intro
ninja video    # 字幕つき動画
```

Azure TTS を使う場合は `key.ninja` に API キーを設定してから `ninja video-audio` を実行します。

---

## 次のステップ

Azure TTS での音声合成、limit / dry-run を使った効率的な進め方、
文節・句読点・読みの調整など、詳しい使い方は [tutorial.md](tutorial.md) を参照してください。

---

## 必要な環境

`ros`（Roswell）/ `mecab` / `npx`（Node.js）/ `gst-launch-1.0`（GStreamer）/ `sox` / `ffmpeg`

インストール手順は [install.md](install.md) を参照してください。

Azure TTS を使う場合は Azure Speech のサブスクリプションキーが別途必要です。
