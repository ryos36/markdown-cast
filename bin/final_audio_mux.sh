#!/bin/sh
# final_audio_mux.sh -- wavlist.ss の全エントリの音声を、通し番号(running)の位置に重ねて
# final 字幕動画に音声をつける(try-final-audio.sh の全件・本番版)。
#
#   - 各エントリ ("orig" "new" A factor B ms n new-rate running "final") から
#     A(=元 wav 番号), new-rate, running を使う。
#   - src = ORIG_WAV_DIR/output.{A}.wav。new-rate > 1.0 なら sox tempo で速めて
#     FINAL_WAV_DIR/output.{running}.wav に出す。<= 1.0 なら無加工でコピー。
#   - 差し込み位置(遅延) = HEAD_MS + (running - 1) * FRAME_MS。
#   - 全 wav を adelay で遅らせ amix で合成(sample-script/ffmpeg-audio-overlay.sh と同方式)。
#
# 環境変数:
#   VIDEO         入れ込む先の動画(字幕付き・音声なし。必須)
#   OUT           出力 mp4(必須)
#   WAVLISTSS     wavlist.ss(必須)
#   HEAD_MS       頭の余白(既定 50。capms 側 head と一致)
#   FRAME_MS      1 コマの長さ ms(既定 800。capms と一致)
#   ORIG_WAV_DIR  元 wav のディレクトリ(既定: _build/orig-wav)
#   FINAL_WAV_DIR tempo 変換後 wav の出力先(既定: _build/final-wav)
#   DRY=1         ffmpeg を実行せず組み立てたコマンドを表示するだけ
set -eu

VIDEO=${VIDEO:?VIDEO を指定してください}
OUT=${OUT:?OUT を指定してください}
WAVLISTSS=${WAVLISTSS:?WAVLISTSS を指定してください}
HEAD_MS=${HEAD_MS:-50}
FRAME_MS=${FRAME_MS:-800}
ORIG_WAV_DIR=${ORIG_WAV_DIR:-_build/orig-wav}
FINAL_WAV_DIR=${FINAL_WAV_DIR:-_build/final-wav}

mkdir -p "${FINAL_WAV_DIR}"
rm -f "${FINAL_WAV_DIR}"/output.*.wav

# wavlist.ss から "A new-rate running" を 1 行ずつ取り出して一時ファイルに置く
# (パイプにすると while がサブシェルになり set -- が効かないため、ファイル経由で読む)。
LIST="${FINAL_WAV_DIR}/.audio-list.txt"
ros -e "(with-open-file (in \"${WAVLISTSS}\")
           (dolist (e (read in))
             (format t \"~d ~,3f ~d~%\" (nth 2 e) (float (nth 7 e) 1d0) (nth 8 e))))" \
  > "${LIST}"

# new-rate に応じて final-wav を用意しつつ、ffmpeg の入力と filter を組み立てる。
set -- ffmpeg -y -hide_banner -i "${VIDEO}"
filter=""
labels=""
i=1
while read -r a rate running; do
    [ -n "${a:-}" ] || continue
    src="${ORIG_WAV_DIR}/output.$(printf '%03d' "${a}").wav"
    dst="${FINAL_WAV_DIR}/output.$(printf '%03d' "${running}").wav"
    if awk "BEGIN{exit !(${rate} > 1.0)}"; then
        sox "${src}" "${dst}" tempo "${rate}"
        tag="sox ${rate}"
    else
        cp "${src}" "${dst}"
        tag="orig"
    fi
    delay=$(( HEAD_MS + (running - 1) * FRAME_MS ))
    set -- "$@" -i "${dst}"
    filter="${filter}[${i}:a]adelay=${delay}|${delay}[a${i}];"
    labels="${labels}[a${i}]"
    echo "  A=${a} running=${running} delay=${delay}ms  ${tag}" >&2
    i=$(( i + 1 ))
done < "${LIST}"
n=$(( i - 1 ))
if [ "${n}" -lt 1 ]; then
    echo "final_audio_mux: ${WAVLISTSS} に wav がありません" >&2
    exit 1
fi

set -- "$@" -filter_complex "${filter}${labels}amix=inputs=${n}:duration=longest:normalize=0[aout]" \
        -map 0:v -map "[aout]" -c:v copy -c:a aac "${OUT}"

if [ -n "${DRY:-}" ]; then
    echo "command:" >&2
    echo "  $*" >&2
    exit 0
fi

echo "  -> ${OUT} (${n} 件)" >&2
exec "$@"
