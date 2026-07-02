# Podman 環境の構想と計画

## 段階計画

一気に本格実装はせず、捨て環境で動作を確認してから本格環境に移る。

### フェーズ 1: 捨て環境が動く（最小イメージ）

- `podman/Containerfile` を作る（最小ベース＋bash のみ）。
- `podman build` → `podman run --rm -it ... bash` で bash 起動を確認。
- ゴール: イメージ build 〜 起動のサイクルが回ること。

### フェーズ 2: 捨て環境で init.sh 〜 build を試す

- Containerfile に依存を追加（ros+Quicklisp(adopt/dexador/babel) / mecab+辞書 /
  node+marp / gstreamer(base/good/ugly) / fonts-noto-cjk / sox / ffmpeg）。
  捨て環境なので雑でよい。動くことの確認が目的。
- markdown-cast と作業ディレクトリをマウントし、コンテナ内で init.sh → `ninja video`
  （--dry-run / Azure 不要）を試す。
- ゴール: mp4 まで通るか確認。詰まり箇所（marp の Chromium / mecab 辞書 / フォント等）を洗い出す。

### フェーズ 3: 本格 podman 環境

- フェーズ 2 の知見で構想（後述）を実装する。
  `init.sh --container` / rules.ninja のコンテナ版 command / 正式 Containerfile。
- 捨て環境は本格版に置き換える。

---

## 目的とユーザー体験

依存ツールが多く（ros / mecab / marp / gstreamer / sox / ffmpeg / fonts-noto-cjk）、
環境差が出やすい。これらをコンテナに閉じ込め、ユーザーは従来どおり `ninja` と打つだけで
mp4 が作れるようにする。コンテナは裏方で動き、ユーザーが意識することはない。

```sh
# セットアップ（初回のみ。イメージのビルドが走る）
sh markdown-cast/bin/init.sh --container slide0

# 以後は普通に ninja するだけ
cd slide0
ninja video          # コンテナ内でビルドが走り、ホストに mp4 ができる
```

---

## ランタイム

**Podman** を使う。rootless がデフォルトで、特殊な設定なしにホスト uid でファイルを書き出せる。
Apple Silicon では `podman machine init` で arm64 の軽量 VM を立て、その上でコンテナを動かす。

---

## 透過化の仕組み

`init.sh --container` が生成する `build.ninja` の各ルールの `command` を
コンテナ実行コマンドで包む。

通常の rule（ホスト実行）:
```
rule bunsetu
  command = ros $bin/mapcar.ros ... -i $src -o $out
```

コンテナ版:
```
rule bunsetu
  command = podman run --rm $ct_vol markdown-cast:latest \
              ros /markdown-cast/bin/mapcar.ros ... -i $src -o $out
```

- `$ct_vol` — マウント指定（下記参照）

ninja の依存追跡はホスト上のファイルタイムスタンプで従来どおり動く。実行だけコンテナ内。

---

## マウント設計

コンテナから見えるべきディレクトリ:

| ホスト側 | コンテナ内 | 内容 |
|----------|------------|------|
| `./`（作業ディレクトリ） | `/work` | deck.md / _build / key.ninja |
| `./share`（辞書） | `/work/share` | mecab-private.dict.ss 等 |
| `<markdown-cast>` | `/markdown-cast` | bin / share / templates |

`bin = /markdown-cast/bin`、作業パスが `/work` で完結するため、相対パス問題は起きない。
コンテナ内でのカレントは `/work` に固定する（`--workdir /work`）。

key.ninja は `/work` 直下にあるため、作業ディレクトリのマウントで自動的にコンテナ内から
見える（コミットしないことは変わらない）。

---

## ファイル所有権

Podman（rootless）の userns マッピングにより、コンテナが書いたファイルは自動的に
ホストの実行ユーザー所有になる。追加設定は基本不要。

---

## Azure キーの受け渡し

key.ninja の `key` 変数はコンテナ内から `/work/key.ninja` 経由で参照できる。
ninja がホスト側で変数を展開してからコンテナへコマンドとして渡すため、
キー文字列がコンテナ環境変数に残らない。`--dry-run` 時は Azure 通信は起きないのでキーは不要。

---

## init.sh --container の役割

1. イメージが未ビルドなら `podman build` を走らせる。
2. コンテナ版の `build.ninja` を生成する（`$ct_vol` を埋め、rule の command を
   コンテナ実行形式にしたもの）。
3. 通常の `init.sh`（`--container` なし）はホスト実行版の build.ninja を生成する（従来どおり）。

---

## イメージ内容（Containerfile）

ベースは arm64/amd64 両対応の Debian 系（例: `debian:bookworm-slim`）。

- `ros`（Roswell）+ Quicklisp + `adopt` / `dexador` / `babel`
- `mecab` + 辞書（ipadic または jumandic — 実装フェーズで選定）
- `node` + `marp-cli`（グローバルインストール。実行時にネット不要にする）
- `gstreamer1.0-tools` + `plugins-base` / `plugins-good` / `plugins-ugly`
- `fonts-noto-cjk`（textoverlay の文字化け防止）
- `sox` / `ffmpeg`
- `ninja`

---

## 未決事項（実装フェーズで詰める）

- mecab 辞書の選択（ipadic か jumandic か。文節結果に差が出る場合がある）
- marp CLI の Chromium sandbox 設定（`--no-sandbox` フラグが要るかどうか）
- Podman machine の初期化コマンドを init.sh に含めるか、ユーザーが別途セットアップするか
- `$ct_vol` の正確な書き方（`:z` フラグの要否）
- rootless uid マッピングの実挙動確認（フェーズ 2 で洗い出す）
