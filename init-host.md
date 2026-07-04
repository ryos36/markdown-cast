# init-host.sh — ホスト実行版の使い方

標準の `init.sh` はビルドを podman コンテナ内で実行します。
`init-host.sh` はコンテナを使わず、ホストにインストールしたツールで
ビルドする構成の足場を作ります。

次のような場合に使います。

- podman を使いたくない、または使えない環境
- 変換ツール群（ros / mecab / marp / gstreamer / sox / ffmpeg）を
  ホストに直接インストールして使いたい場合

---

## 事前準備

必要なツールのインストール手順は [install.md](install.md) を参照してください。

---

## 使い方

手順は README の「始め方」と同じで、`init.sh` を `init-host.sh` に
読み替えるだけです。

```sh
mkdir my-slides && cd my-slides
git init
git submodule add https://github.com/ryos36/markdown-cast

sh markdown-cast/bin/init-host.sh my-first-slide

cd my-first-slide
$EDITOR deck.md      # スライドと発話ノートを書く
ninja video          # 字幕つき動画（Azure 不要）
```

実行すると環境チェックが走り、不足しているツールが `[MISSING]` で表示されます。

生成されるファイル（`deck.md`・`build.ninja`・`key.ninja`・`share/` の辞書）は
`init.sh` と同じです。違いは `build.ninja` の中身だけで、
ホスト実行用のビルドルール（`rules.ninja`）を参照します。

---

## podman 版との同居

同じ作業ディレクトリに `init.sh` で作った deck と `init-host.sh` で作った deck を
並べて置けます。それぞれ独立してビルドでき、互いに干渉しません。

deck を後からもう一方の構成に切り替えたい場合は、その deck の `build.ninja` を
作り直します（`deck.md`・`key.ninja`・辞書はそのまま使えます）。

---

## Azure TTS

音声つき動画（`ninja video-audio`）の作り方は podman 版と共通です。
[azure.md](azure.md) と [tutorial.md](tutorial.md) を参照してください。
