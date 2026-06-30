# Azure TTS の設定

`ninja final-caption-audio.mp4`（音声つき最終動画）には Azure Cognitive Services の Speech サービスが必要。
`ninja with-caption.mp4`（字幕のみ動画）には不要。

---

## 準備

1. [Azure ポータル](https://portal.azure.com/) でサブスクリプションを作成する
2. **Cognitive Services → Speech** リソースを作成する
3. リソースの「キーとエンドポイント」から **キー1**（または キー2）と **場所/リージョン** を控える

---

## build.ninja への設定

生成された `build.ninja` の以下の行のコメントを外して値を入れる:

```ninja
key    = ここにキーを貼る
region = japaneast          # リソース作成時に選んだリージョン
voice  = ja-JP-NanamiNeural # 使いたい音声名
```

利用可能な音声名は [Azure 音声ギャラリー](https://speech.microsoft.com/portal/voicegallery) で確認できる。

### セキュリティ上の注意

- **`build.ninja` をコミットしないこと**（キーが漏洩する）
- `.gitignore` に `build.ninja` を追加するか、キーの行だけ別ファイルに切り出して管理する

---

## 動作確認（課金なし）

キーを設定する前に `--dry-run` で流れを確認できる:

```ninja
# build.ninja の wav_extra_options をコメントアウトして:
wav_extra_options = --dry-run
```

```sh
ninja final-caption-audio.mp4
```

実際の Azure 通信は行わず、文節数 × 200ms で wav 長を見積もる。

---

## コスト

Azure Speech の無料枠は月 500 万文字（F0 tier）。スライド動画の用途では通常無料枠に収まる。
