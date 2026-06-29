#!/bin/sh
# init.sh — markdown-cast プロジェクトの足場を作る
#
# 使い方:
#   sh markdown-cast/bin/init.sh           # 単発: カレントに直接 deck.md / build.ninja を置く
#   sh markdown-cast/bin/init.sh slide0    # 複数: slide0/ サブディレクトリに置く（辞書は share/ に共通化）

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MKC=$(cd "$SCRIPT_DIR/.." && pwd)
SUBMOD=$(basename "$MKC")
TMPL="$MKC/templates/default"

# ---- 環境チェック ----
echo "Checking environment..."
MISSING=0
check_tool() {
    if command -v "$1" > /dev/null 2>&1; then
        printf "  [OK]      %s\n" "$1"
    else
        printf "  [MISSING] %s  → %s\n" "$1" "$2"
        MISSING=1
    fi
}
check_tool ros           "https://roswell.github.io/"
check_tool mecab         "apt install mecab libmecab-dev mecab-ipadic-utf8"
check_tool npx           "apt install nodejs npm"
check_tool gst-launch-1.0 "apt install gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly"
check_tool sox           "apt install sox"
check_tool ffmpeg        "apt install ffmpeg"
check_tool ninja         "apt install ninja-build"

if [ "$MISSING" -eq 1 ]; then
    echo ""
    echo "  ※ 不足ツールがありますが、足場の生成は続けます。"
fi
echo ""

# ---- モード判定 ----
NAME="$1"
if [ -z "$NAME" ]; then
    # 単発（フラット）
    DESTDIR="."
    BIN="$SUBMOD/bin"
    SHARE="."
    RULES="$SUBMOD/share/rules.ninja"
    DICT_DIR="."
else
    # 複数（サブディレクトリ）
    DESTDIR="$NAME"
    BIN="../$SUBMOD/bin"
    SHARE="../share"
    RULES="../$SUBMOD/share/rules.ninja"
    DICT_DIR="share"
fi

# ---- 辞書を配置 ----
if [ "$DICT_DIR" != "." ]; then
    mkdir -p "$DICT_DIR"
fi
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
if [ -n "$NAME" ]; then
    mkdir -p "$DESTDIR"
fi
NINJA_DST="$DESTDIR/build.ninja"
if [ -e "$NINJA_DST" ]; then
    echo "  [skip]    $NINJA_DST（既存）"
else
    sed -e "s|@BIN@|$BIN|g" \
        -e "s|@SHARE@|$SHARE|g" \
        -e "s|@RULES@|$RULES|g" \
        "$TMPL/build.ninja.in" > "$NINJA_DST"
    echo "  [create]  $NINJA_DST"
fi

# ---- deck.md を配置 ----
DECK_DST="$DESTDIR/deck.md"
copy_if_missing "$TMPL/deck.md" "$DECK_DST"

# ---- 完了メッセージ ----
echo ""
echo "Done."
if [ -n "$NAME" ]; then
    echo ""
    echo "  次のステップ:"
    echo "    cd $NAME"
    echo "    ninja with-caption.mp4        # 字幕つき動画（Azure 不要）"
    echo "    ninja final-caption-audio.mp4 # 音声つき最終動画（Azure 必要: build.ninja の key/region/voice を設定）"
else
    echo ""
    echo "  次のステップ:"
    echo "    ninja with-caption.mp4        # 字幕つき動画（Azure 不要）"
    echo "    ninja final-caption-audio.mp4 # 音声つき最終動画（Azure 必要: build.ninja の key/region/voice を設定）"
fi
