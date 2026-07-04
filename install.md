# 環境のセットアップ（ホスト実行版）

ツールをホストに直接インストールして markdown-cast（`init-host.sh`）を動かすための手順です。

podman でビルドする場合（標準の `init.sh`）はこのページの作業は不要です。
podman と ninja だけインストールしてください（README 参照）。

Ubuntu / Debian 系を前提に書いています。

---

## 必要なツール一覧

| ツール | 用途 |
|--------|------|
| `ros`（Roswell） | Common Lisp スクリプト群の実行 |
| `mecab` + 辞書 | 日本語テキストの形態素解析 |
| `npx`（Node.js） | Marp CLI |
| `gst-launch-1.0`（GStreamer） | PNG から MP4 への変換（字幕焼き込み） |
| `fonts-noto-cjk` | GStreamer の字幕描画に使うフォント |
| `sox` | wav の実測・速度変換 |
| `ffmpeg` | 音声と動画の合成 |
| `ninja` | ビルドシステム |
| Azure Speech サブスクリプション | 音声合成（★課金。音声つき動画にのみ必要） |

---

## apt でインストールできるもの

```sh
sudo apt install \
    mecab libmecab-dev mecab-ipadic-utf8 \
    gstreamer1.0-tools \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-ugly \
    fonts-noto-cjk \
    sox \
    ffmpeg \
    ninja-build \
    nodejs npm
```

---

## Roswell（ros）

Roswell は Common Lisp の処理系・スクリプト実行環境です。

公式のインストール手順: https://roswell.github.io/

Ubuntu の場合:

```sh
curl -L https://github.com/roswell/roswell/releases/download/v24.10.14.114/roswell_24.10.14.114-1_amd64.deb \
     -o roswell.deb
sudo dpkg -i roswell.deb
ros setup
```

バージョンは最新のものを https://github.com/roswell/roswell/releases で確認してください。

---

## Lisp ライブラリ（QuickLisp 経由）

Roswell をセットアップ後、初回スクリプト実行時に自動でインストールされます。
手動で入れる場合:

```sh
ros -e "(ql:quickload '(:adopt :dexador :babel))"
```

---

## MeCab 辞書の確認

```sh
echo "テスト" | mecab
```

正しく品詞分解されれば OK です。

---

## 動作確認

`init-host.sh` を実行すると環境チェックが走り、不足しているツールを教えてくれます。

```sh
sh markdown-cast/bin/init-host.sh --help
```

または実際に足場を作ってみます。

```sh
sh markdown-cast/bin/init-host.sh test-slide
```

`[OK]` / `[MISSING]` で各ツールの有無が表示されます。
