# Podman 環境の構想と計画

## 実現可能性と段階計画

フェーズ1（最小イメージ動作確認）・フェーズ2（init.sh 〜 ninja video 検証）は完了済み。
以下は本格実装に向けた計画。

### 透過化の鍵: `$run` ラッパ変数

`rules.ninja` の各 rule command の先頭に変数 `$run` を付ける。

```
rule bunsetu
  command = $run ros $bin/mapcar.ros ...
```

- **ホスト実行**: `run` を定義しない（ninja の未定義変数は空展開）。コマンドは従来と完全一致。
  既存の build.ninja は変更不要。壊れない。
- **コンテナ実行**: build.ninja 側で `run = podman run --rm $ct_vol markdown-cast:v1` を定義。
  ninja がコマンドを展開するとき自動的にコンテナ実行になる。

### バージョン混在の鍵: イメージタグ + ディレクトリごとの `image` 変数

Containerfile をバージョンごとにディレクトリで管理する（`podman/v1/`, `podman/v2/`, ...）。
各バージョンを別タグでビルド（`markdown-cast:v1`, `markdown-cast:v2`）。

各スライドディレクトリの build.ninja は `image = markdown-cast:v1` のように使うタグを持つ。
- v1 で動いているディレクトリはそのまま v1 を使い続ける。
- 新ディレクトリだけ v2 を使う。
- ホスト実行のディレクトリは `run` を定義しないだけ。

3 種が同居でき、互いに干渉しない。

### フェーズ 1: `$run` ラッパを rules.ninja に導入

- `share/rules.ninja` の全 rule command 先頭に `$run` を追加。
- ホスト実行（`run` 未定義）で既存テストが全件 PASS することを `lit test/` で確認。

### フェーズ 2: Containerfile をバージョン管理に移行

- 現 `podman/Containerfile`（検証済み）を `podman/v1/Containerfile` に移す。
- `podman build -t markdown-cast:v1 podman/v1/` でタグ付きビルド。
- `.gitignore` を整理（`podman/work/` は維持）。

### フェーズ 3: `init.sh --container <NAME>` を実装

- サブディレクトリモード（NAME あり）のみ対応。フラットは非対応。
- コンテナ版 build.ninja を生成する（`run` / `image` / コンテナ内 bin・share パス）。
- 通常の `init.sh <NAME>`（コンテナなし）はそのまま使える。

### フェーズ 4: マウントとファイル所有権の確定

- マウント設計: ホスト `./NAME` を `/work` に、markdown-cast を `/work/markdown-cast` にマウント。
- Podman rootless userns でホスト uid に書き出されることを実機確認。
- Azure キー（`key.ninja`）は `/work` マウントに含まれるため追加対応不要。

### フェーズ 5: 混在検証

- ホスト実行 / v1 / v2 の 3 ディレクトリを同じ親に置き、それぞれ独立して ninja が動くことを確認。

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
