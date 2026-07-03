#!/bin/sh
# init-podman.sh — markdown-cast プロジェクトの足場を作る（podman 版）
#
# ホスト実行用の init.sh には触れない別セット。
# rules-podman.ninja / templates/podman を参照する build.ninja を生成する。
#
# 使い方:
#   sh markdown-cast/bin/init-podman.sh <NAME>    # NAME/ サブディレクトリに足場を生成する（辞書は share/ に共通化）

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MKC=$(cd "$SCRIPT_DIR/.." && pwd)
SUBMOD=$(basename "$MKC")
TMPL="$MKC/templates/podman"

# ---- 環境チェック ----
echo "Checking environment..."
MISSING=0
check_tool() {
    if command -v "$1" > /dev/null 2>&1; then
        printf "  [OK]      %s\n" "$1"
    else
        printf "  [MISSING] %s  -- %s\n" "$1" "$2"
        MISSING=1
    fi
}
check_tool podman        "apt install podman"
check_tool ninja         "apt install ninja-build"

if [ "$MISSING" -eq 1 ]; then
    echo ""
    echo "  ※ 不足ツールがありますが、足場の生成は続けます。"
fi
echo ""

# ---- 引数チェック ----
NAME="$1"
if [ -z "$NAME" ]; then
    echo "使い方: sh markdown-cast/bin/init-podman.sh <NAME>"
    exit 1
fi

# ---- パス設定 ----
DESTDIR="$NAME"
# bin はコンテナ内パス（rule の command でのみ使われる）
BIN="/markdown-cast/bin"
# 辞書は ninja の依存関係にも使われるためホスト側の相対パス
MECAB_DICT="../share/mecab-private.dict.ss"
PRON_DICT="../share/pronunciation.dict.ss"
RULES="../$SUBMOD/share/rules-podman.ninja"
DICT_DIR="share"
DECK="$NAME"
# 使用するコンテナイメージ
IMAGE="localhost/markdown-cast:v1"
CONTAINERFILE_DIR="$MKC/podman/v1"

# ---- イメージの確認とビルド ----
if command -v podman > /dev/null 2>&1; then
    if podman image exists "$IMAGE"; then
        echo "  [OK]      イメージ $IMAGE"
    else
        echo "  [build]   イメージ $IMAGE をビルドします（初回は数分かかります）"
        podman build -t "$IMAGE" "$CONTAINERFILE_DIR"
    fi
else
    echo "  [skip]    podman がないためイメージの確認をスキップします"
fi
echo ""

# ---- 辞書を配置 ----
mkdir -p "$DICT_DIR"
copy_if_missing() {
    src="$1"
    dst="$2"
    if [ -e "$dst" ]; then
        echo "  [skip]    $dst（既存）"
    else
        cp "$src" "$dst"
        echo "  [create]  $dst"
    fi
}
copy_if_missing "$TMPL/pronunciation.dict.ss"  "$DICT_DIR/pronunciation.dict.ss"
copy_if_missing "$TMPL/mecab-private.dict.ss"  "$DICT_DIR/mecab-private.dict.ss"

# ---- build.ninja を生成 ----
mkdir -p "$DESTDIR"
NINJA_DST="$DESTDIR/build.ninja"
if [ -e "$NINJA_DST" ]; then
    echo "  [skip]    $NINJA_DST（既存）"
else
    sed -e "s|@BIN@|$BIN|g" \
        -e "s|@MECAB_DICT@|$MECAB_DICT|g" \
        -e "s|@PRON_DICT@|$PRON_DICT|g" \
        -e "s|@RULES@|$RULES|g" \
        -e "s|@DECK@|$DECK|g" \
        -e "s|@IMAGE@|$IMAGE|g" \
        "$TMPL/build.ninja.in" > "$NINJA_DST"
    echo "  [create]  $NINJA_DST"
fi

# ---- key.ninja を配置 ----
copy_if_missing "$TMPL/key.ninja" "$DESTDIR/key.ninja"

# ---- .gitignore に key.ninja を追加 ----
GITIGNORE="$DESTDIR/.gitignore"
if grep -qsF "key.ninja" "$GITIGNORE"; then
    echo "  [skip]    $GITIGNORE（key.ninja 既存）"
else
    echo "key.ninja" >> "$GITIGNORE"
    echo "  [update]  $GITIGNORE（key.ninja を追加）"
fi

# ---- deck.md を配置 ----
DECK_DST="$DESTDIR/deck.md"
copy_if_missing "$TMPL/deck.md" "$DECK_DST"

# ---- 完了メッセージ ----
echo ""
echo "Done."
echo ""
echo "  次のステップ:"
echo "    cd $NAME"
echo "    \$EDITOR deck.md   # 発話ノートを <!-- --> で書く"
echo "    ninja              # ${DECK}.mp4 と ${DECK}.pdf を生成（Azure 不要）"
echo ""
echo "  音声つき動画を作る場合（Azure TTS が必要）:"
echo "    \$EDITOR key.ninja  # key / region / voice を設定（$SUBMOD/azure.md 参照）"
echo "    ninja video-audio  # ${DECK}-audio.mp4 を生成"
