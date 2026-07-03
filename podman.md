# Podman 環境の構想と計画

## 実現可能性と段階計画

フェーズ1（最小イメージ動作確認）・フェーズ2（init.sh 〜 ninja video 検証）は完了済み。
以下は本格実装に向けた計画。

### 方針: 既存環境に触れない「-podman 別セット」

最終形は podman あり / なしの混在なので、ホスト実行環境は今後もずっと使い続ける。
共有ファイルを書き換える方式（`$run` ラッパ変数の導入）はやめ、
podman 用のファイルを別セットとして新設する。

- ホスト実行用（`bin/init.sh`、`share/rules.ninja`、`templates/default/`、
  `bin/*.ros`、`bin/*.sh`）は一切変更しない。
- podman 用は別ファイル: `bin/init-podman.sh`、`share/rules-podman.ninja`、
  `templates/podman/`。
- bin のスクリプトに修正が必要になった場合も、`abc.ros` なら `abc-podman.ros`、
  `abc.sh` なら `abc-podman.sh` のようにコピーしてから直す（冗長でもよい）。
- 試験は .gitignore 済みの `podman/work2/` で行う。markdown-cast への symlink を置き、

  ```sh
  cd podman/work2
  sh markdown-cast/bin/init-podman.sh <NAME>
  cd <NAME> && ninja video
  ```

### バージョン混在の鍵: イメージタグ + ディレクトリごとの `image` 変数

Containerfile をバージョンごとにディレクトリで管理する（`podman/v1/`, `podman/v2/`, ...）。
各バージョンを別タグでビルド（`markdown-cast:v1`, `markdown-cast:v2`）。

各スライドディレクトリの build.ninja は `image = markdown-cast:v1` のように使うタグを持つ。
- v1 で動いているディレクトリはそのまま v1 を使い続ける。
- 新ディレクトリだけ v2 を使う。
- ホスト実行のディレクトリは従来どおり rules.ninja を include するだけ。

3 種が同居でき、互いに干渉しない。

### フェーズ 1: 別セットの足場を作る -- 完了（2026-07-04）

- `share/rules-podman.ninja` を rules.ninja のコピーとして新設。
- `templates/podman/` を templates/default のコピーとして新設。
- `bin/init-podman.sh` を新設（templates/podman と rules-podman.ninja を参照。
  環境チェックは podman / ninja のみ）。
- `podman/work2/slide0` でホスト実行のまま `ninja video` が通ることを確認済み。
  lit テスト 37 件も PASS のまま。

### フェーズ 2: rules-podman.ninja をコンテナ実行に書き換え -- 完了（2026-07-04）

- 全 rule を `$run`（= `podman run --rm --workdir /work $ct_vol $image`）付きに書き換え、
  `podman/work2/slide0` で video / video-audio / pdf の全ターゲットが通ることを確認済み。
- note2ss / bunsetu / caption / srt はホスト実行と出力が一致することも確認済み。
- frame_link / final_frame_link / clean 系はホスト側のファイル操作だけなのでコンテナを使わない。
- marp はイメージ内のグローバルインストール版を使う（npx は使わない）。
  Chromium は追加フラグなしで動いた。
- `mkdir` / `touch` / 出力リダイレクト（`> $out`）はホスト側の sh が処理する。
- final_audio_mux の環境変数は `$run env VAR=... sh ...` の形でコンテナ内に渡す。
- 辞書はコンテナ内パス用の変数（`ct_mecab_dict` / `ct_pron_dict`）を command に使い、
  ホスト相対パス（`mecab_dict` / `pron_dict`）は ninja の依存関係用に残す。
- コンテナが書いたファイルはホスト uid（実行ユーザー）所有になることを確認済み
  （フェーズ 4 の実機確認の一部を前倒しで完了）。

### フェーズ 3: Containerfile をバージョン管理に移行 -- 完了（2026-07-04）

- `podman/Containerfile` を `podman/v1/Containerfile` に移動（git mv）。
- `podman build -t markdown-cast:v1 podman/v1/` でタグ付きビルド
  （レイヤーキャッシュにより既存イメージと同一 ID に v1 タグが付いた）。
- init-podman.sh にイメージ確認を組み込み: 未ビルドなら
  「初回は数分かかります」と表示して `podman build` を実行する。
  podman がない環境ではスキップして足場生成だけ続ける。
- `podman/work2/` の slide0（タグ切り替え後の再ビルド）と slide1（新規 init）の
  両方で全ターゲットが v1 イメージで通ることを確認済み。

### フェーズ 4: マウントとファイル所有権の確定 -- Linux 分は完了

- マウントは rules-podman.ninja の `ct_vol` で確定済み（「マウント設計」の表を参照）。
- rootless userns でホスト uid に書き出されることは Linux（Ubuntu）で確認済み。
- Azure キー（`key.ninja`）は `/work` マウントに含まれるため追加対応不要。
- 残り: Apple Silicon（podman machine 経由）での実機確認。

### テスト -- 追加済み（2026-07-04）

- `test/podman/01-init-podman.test`: init-podman.sh の足場生成から
  `ninja video pdf video-audio` までの通しテスト。`REQUIRES: ninja, podman`
  （他ツールはコンテナ内にあるため、ホストには podman と ninja だけあればよい）。
- `test/lit.cfg.py` に podman の feature 登録を追加。

### フェーズ 5: 混在検証

- ホスト実行 / v1 / v2 の 3 ディレクトリを同じ親に置き、それぞれ独立して ninja が動くことを確認。

---

## 目的とユーザー体験

依存ツールが多く（ros / mecab / marp / gstreamer / sox / ffmpeg / fonts-noto-cjk）、
環境差が出やすい。これらをコンテナに閉じ込め、ユーザーは従来どおり `ninja` と打つだけで
mp4 が作れるようにする。コンテナは裏方で動き、ユーザーが意識することはない。

```sh
# セットアップ（初回のみ。イメージのビルドが走る）
sh markdown-cast/bin/init-podman.sh slide0

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

コンテナ実行コマンドは `share/rules-podman.ninja` に持つ。
`init-podman.sh` が生成する `build.ninja` はこれを include する
（ホスト実行の rules.ninja とは別ファイルなので互いに干渉しない）。

通常の rule（rules.ninja、ホスト実行）:
```
rule bunsetu
  command = ros $bin/mapcar.ros ... -i $src -o $out
```

コンテナ版（rules-podman.ninja）:
```
run = podman run --rm --workdir /work $ct_vol $image

rule bunsetu
  command = $run ros $bin/mapcar.ros ... -i $src -o $out
```

- `$ct_vol` — マウント指定（下記参照）
- `$image` — 使うイメージタグ。各 deck の build.ninja が定義する
- `$bin` — コンテナ内パス（`/markdown-cast/bin`）。build.ninja が定義する
- `mkdir` / `touch` / 出力リダイレクト（`> $out`）はホスト側の sh が処理する
- frame_link / final_frame_link / clean 系はファイル操作だけなのでコンテナを使わない

ninja の依存追跡はホスト上のファイルタイムスタンプで従来どおり動く。実行だけコンテナ内。

---

## マウント設計

コンテナから見えるべきディレクトリ:

| ホスト側 | コンテナ内 | 内容 |
|----------|------------|------|
| `./`（作業ディレクトリ） | `/work` | deck.md / _build / key.ninja |
| `../share`（親の辞書ディレクトリ） | `/work/share` | mecab-private.dict.ss 等 |
| `../markdown-cast` | `/markdown-cast` | bin / share / templates |

rules-podman.ninja での実際の定義:

```
ct_vol = -v $$PWD:/work -v $$PWD/../share:/work/share -v $$PWD/../markdown-cast:/markdown-cast
```

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

## init-podman.sh の役割

1. イメージが未ビルドなら `podman build` を走らせる。
2. `templates/podman/` から `build.ninja` を生成する（rules-podman.ninja を include）。
3. 通常の `init.sh` はホスト実行版の build.ninja を生成する（従来どおり、無変更）。

---

## イメージ内容（podman/v1/Containerfile）

ベースは arm64/amd64 両対応の `debian:bookworm-slim`。

- `sbcl` + `ros`（Roswell）+ Quicklisp + `adopt` / `dexador` / `babel`
- `mecab` + ipadic（ホスト実行と同じ文節結果になることを確認済み）
- `node` + `marp-cli`（グローバルインストール。実行時にネット不要）
- `chromium`（marp の PDF / PNG 変換用。PUPPETEER_EXECUTABLE_PATH で指定）
- `gstreamer1.0-tools` + `plugins-base` / `plugins-good` / `plugins-ugly` / `gstreamer1.0-x`
  （gstreamer1.0-x は textoverlay に必要）
- `fonts-noto-cjk`（textoverlay の文字化け防止）
- `sox` / `ffmpeg`
- `ninja`

---

## 未決事項（実装フェーズで詰める）

- Podman machine の初期化コマンドを init-podman.sh に含めるか、ユーザーが別途セットアップするか
- `$ct_vol` の `:z` フラグの要否（SELinux 環境。手元の Ubuntu では不要だった）

## 解決済み（フェーズ 2 で確認）

- mecab 辞書: イメージの ipadic でホスト実行と同じ文節結果になった（slide0 で確認）
- marp CLI の Chromium sandbox: 追加フラグなしで動いた
- rootless uid マッピング: コンテナが書いたファイルはホストの実行ユーザー所有になった
