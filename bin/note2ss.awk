#!/usr/bin/awk -f
#
# note2ss.awk -- Marp の md から発話ノートを 1 個の S 式(リスト)に変換する。
#
# 発話ノートは Marp の HTML コメント <!-- ... --> として書かれている前提。
# 1 スライドのノート(複数行)を連結して 1 文字列にし、全スライドを 1 個の
#   ("1枚目のノート" "2枚目のノート" ...)
# というリストにまとめて出力する。ノートが無いスライドはスキップする。
#
# 使い方: awk -f note2ss.awk event2026-08.md > _build/note.ss

BEGIN {
    in_front = 0    # YAML frontmatter の内側か
    in_note  = 0    # コメントブロックの内側か
    buf      = ""   # 現スライドのノート(連結中)
    ns       = 0    # 確定したスライド数
}

# 行末の CR を除去(CRLF 対策)
{ sub(/\r$/, "") }

# --- 先頭の YAML frontmatter を読み飛ばす ---
# 1 行目が --- なら frontmatter 開始。次の --- で終了。
NR == 1 && /^---[ \t]*$/ {
    in_front = 1
    next
}
in_front && /^---[ \t]*$/ {
    in_front = 0
    next
}
in_front {
    next
}

# --- スライド区切り ---
/^---[ \t]*$/ {
    flush()
    next
}

# --- コメント(発話ノート)の処理 ---
{
    line = $0
}

# コメント開始 <!--
!in_note && index(line, "<!--") > 0 {
    in_note = 1
    sub(/.*<!--/, "", line)          # <!-- より前を捨てる
    if (index(line, "-->") > 0) {    # 同一行に --> がある場合
        sub(/-->.*/, "", line)
        in_note = 0
    }
    add(line)
    next
}

# コメント内
in_note {
    if (index(line, "-->") > 0) {
        sub(/-->.*/, "", line)
        add(line)
        in_note = 0
    } else {
        add(line)
    }
    next
}

END {
    flush()
    emit()
}

# ノート行を現スライドのバッファに連結する(前後空白を除去し、空行は捨てる)。
function add(s,    t) {
    t = s
    gsub(/^[ \t]+/, "", t)
    gsub(/[ \t]+$/, "", t)
    if (t == "") {
        return
    }
    buf = buf t
}

# 現スライドのバッファを 1 文字列として確定する(空ならスキップ)。
function flush() {
    if (buf != "") {
        slides[ns] = esc(buf)
        ns++
    }
    buf = ""
}

# S 式の文字列リテラル用にエスケープする(バックスラッシュと二重引用符)。
function esc(s,    t) {
    t = s
    gsub(/\\/, "\\\\", t)
    gsub(/"/,  "\\\"", t)
    return t
}

# 全スライドを 1 個のリスト (...) にして出力する。
function emit(    i, out) {
    out = "("
    for (i = 0; i < ns; i++) {
        if (i > 0) {
            out = out " "
        }
        out = out "\"" slides[i] "\""
    }
    out = out ")"
    print out
}
