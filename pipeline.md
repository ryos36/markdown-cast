# pipeline — 大雑把な実行順

`deck.md` から音声つき最終動画までの、おおまかな処理の順番。
実体は `build.ninja` が依存関係から自動で並べる。ここは流れを追うためのメモ。

## 1. 原稿を取り出す
```
deck.md --(note2ss.awk)--> note.ss          # 発話ノートを S 式リストに
```

## 2. テキスト解析（形態素 → 文節）
```
note.ss --(mapcar: note2word → word2word → word2bunsetu)--> 文節構造
  note2word   mecab で ((単語 . 品詞) …)
  word2word   複合語辞書で 1 語に畳む
  word2bunsetu 助詞・副詞・句読点で文節に区切る
```

## 3. 字幕の枝
```
文節構造 --(bunsetu2caption)--> caption.ss   # N 文字で折り返した字幕の単位
caption.ss --(caption2srt)--> subs.srt       # 字幕
```

## 4. 動画フレームの枝（字幕焼き込み）
```
deck.md --(marp --images png)--> orig-png/    # スライド PNG
caption.ss --(caption2pnglist)--> pnglist.txt # 複製の元/先リスト
pnglist.txt --(ln でハードリンク)--> new-png/  # 1 caption = 1 フレーム
new-png/ + subs.srt --(gstreamer)--> with-caption.mp4   # 字幕焼き込み（音声なし）
```

## 5. 音声の枝（★ここだけ Azure で課金）
```
文節構造 --(bunsetu2tts)--> tts.ss            # 「文ごと」の読み上げ単位
tts.ss --(tts2wav: Azure TTS)--> orig-wav/    # 文ごとの wav（読み辞書・SSML・キャッシュ）
```

## 6. タイミング計算
```
tts.ss + orig-wav/ の実測尺 --(tts2wavlist)--> wavlist.ss
  各文の音声尺 ms と割当フレーム数から factor / n（追加フレーム）/ 通し番号を決める
```

## 7. 速度調整して合成
```
orig-wav/ --(sox tempo: factor 倍速)--> new-wav/
new-wav/ + with-caption.mp4 --(ffmpeg: adelay + amix)--> with-caption-audio.mp4
```

## 8. final（通し番号を振り直した最終版）
速すぎ防止でフレームを足したぶん、番号がずれる。それに合わせて作り直す。
```
wavlist.ss + caption.ss --(ss2finalpng)--> final-png/         # 並べ直し
wavlist.ss + caption.ss --(ss2finalsrt)--> final-subs.srt     # 再タイミング字幕
final-png/ + final-subs.srt --(gstreamer)--> final-caption.mp4
final-caption.mp4 + wavlist.ss --(final_audio_mux)--> final-caption-audio.mp4
```

---

## ninja ターゲットでの呼び方
```
ninja pdf                     # 1（PDF）
ninja png                     # 4 のスライド PNG
ninja srt                     # 1→2→3
ninja with-caption.mp4        # 1→2→3→4
ninja wav                     # 1→2→5（★Azure 課金）
ninja with-caption-audio.mp4  # …→6→7
ninja final-caption-audio.mp4 # …→8
```
`ninja wav` 以外は Azure 不要。
</content>
