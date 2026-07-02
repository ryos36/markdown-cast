#!/bin/sh
# mkwav.sh — txt/ss から wav を作るプロジェクトの足場を作る
#
# 使い方:
#   sh markdown-cast/bin/mkwav.sh [NAME]
#
#   NAME を指定するとその名前でディレクトリを作る。
#   未指定のときは wav-sample/ を使う。
#   ディレクトリがすでに存在する場合はエラーで終了する。

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MKC=$(cd "$SCRIPT_DIR/.." && pwd)
SUBMOD=$(basename "$MKC")
TMPL="$MKC/templates/wav"

# ---- 引数チェック ----
NAME="${1:-wav-sample}"

if [ -e "$NAME" ]; then
    echo "エラー: '$NAME' はすでに存在します。別の名前を指定してください。"
    exit 1
fi

# ---- パス設定 ----
DESTDIR="$NAME"
BIN="../$SUBMOD/bin"
MECAB_DICT="../share/mecab-private.dict.ss"
PRON_DICT="../share/pronunciation.dict.ss"
WAV_RULES="../$SUBMOD/share/wav-rules.ninja"
DICT_DIR="share"

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
copy_if_missing "$MKC/templates/default/pronunciation.dict.ss"  "$DICT_DIR/pronunciation.dict.ss"
copy_if_missing "$MKC/templates/default/mecab-private.dict.ss"  "$DICT_DIR/mecab-private.dict.ss"

# ---- ディレクトリと各ファイルを生成 ----
mkdir -p "$DESTDIR"

NINJA_DST="$DESTDIR/build.ninja"
sed -e "s|@BIN@|$BIN|g" \
    -e "s|@MECAB_DICT@|$MECAB_DICT|g" \
    -e "s|@PRON_DICT@|$PRON_DICT|g" \
    -e "s|@WAV_RULES@|$WAV_RULES|g" \
    "$TMPL/build.ninja.in" > "$NINJA_DST"
echo "  [create]  $NINJA_DST"

cp "$TMPL/sample.txt" "$DESTDIR/sample.txt"
echo "  [create]  $DESTDIR/sample.txt"

copy_if_missing "$MKC/templates/default/key.ninja" "$DESTDIR/key.ninja"

# ---- .gitignore に key.ninja を追加 ----
GITIGNORE="$DESTDIR/.gitignore"
if grep -qsF "key.ninja" "$GITIGNORE"; then
    echo "  [skip]    $GITIGNORE（key.ninja 既存）"
else
    echo "key.ninja" >> "$GITIGNORE"
    echo "  [update]  $GITIGNORE（key.ninja を追加）"
fi

# ---- 完了メッセージ ----
echo ""
echo "Done."
echo ""
echo "  次のステップ:"
echo "    cd $NAME"
echo "    \$EDITOR sample.txt   # 読み上げるテキストを 1 行 1 発話で書く"
echo "    \$EDITOR key.ninja    # key / region / voice を設定（$SUBMOD/azure.md 参照）"
echo "    ninja                # _build/sample.wav を生成（Azure TTS 必要）"
echo ""
echo "  ss 経路（note.ss 形式の .ss ファイルから wav を作る場合）:"
echo "    build.ninja のコメントアウトされた ss 経路の例を参考にしてください。"
