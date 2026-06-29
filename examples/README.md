# examples

markdown-cast のサンプル集。各ディレクトリに `deck.md` と `build.ninja` が入っている。

## 使い方

```sh
cd examples/<ディレクトリ名>
ninja with-caption.mp4        # 字幕つき動画（Azure 不要）
ninja final-caption-audio.mp4 # 音声つき最終動画（Azure 必要）
```

Azure TTS を使う場合は `build.ninja` の `key` / `region` / `voice` を設定すること。

## サンプル一覧

| ディレクトリ | 内容 |
|---|---|
| `hello/` | 骨組みテンプレート。自分のデッキを作るときの出発点 |
| `intro/` | markdown-cast の意義と使い方を説明するスライド |
| `rawls-san/` | ロールズの「無知のヴェール」を題材にしたサンプル |
