#!/bin/sh
set -eu
err() { echo "script.sh: $*" >&2; }
[ $# -eq 1 ] || { err "использование: $0 <файл>"; exit 1; }
SRC=$1
[ -f "$SRC" ] || { err "файл не найден: $SRC"; exit 3; }
[ -r "$SRC" ] || { err "файл не читается: $SRC"; exit 4; }
case "$SRC" in
    *.tex) TOOL=pdflatex ;;
    *.c)   TOOL=cc ;;
    *.cpp)   TOOL=c++ ;;
    *)     err "неподдерживаемый тип файла: $SRC"; exit 2 ;;
esac
command -v "$TOOL" >/dev/null 2>&1 || { err "не найдена утилита: $TOOL"; exit 5; }
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SRC_ABS=$(cd "$(dirname "$SRC")" && pwd)/$(basename "$SRC")
TMPDIR=
cleanup() {
    [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ] && rm -rf "$TMPDIR"
}
trap cleanup EXIT INT TERM HUP
TMPDIR=$(mktemp -d) || { err "не удалось создать временный каталог"; exit 6; }
case "$SRC" in
    *.tex)
        OUTPUT_NAME=$(
            sed -n 's|^[[:space:]]*%[[:space:]]*Output:[[:space:]]*\([^[:space:]]*\)|\1|p' "$SRC" \
                | head -n 1
        )
        [ -n "$OUTPUT_NAME" ] || { err "не найден комментарий 'Output:' в $SRC"; exit 7; }
        cd "$TMPDIR"
        if ! "$TOOL" -interaction=nonstopmode -halt-on-error "$SRC_ABS" >/dev/null 2>&1; then
            err "ошибка сборки TeX: $SRC"
            exit 8
        fi

        SRC_BASE=$(basename "$SRC")
        SRC_BASE=${SRC_BASE%.tex}

        [ -f "$TMPDIR/$SRC_BASE.pdf" ] || { err "PDF не создан: $SRC"; exit 8; }
        mv "$TMPDIR/$SRC_BASE.pdf" "$TMPDIR/$OUTPUT_NAME"
        ;;
    *.c|*.cpp)
        OUTPUT_NAME=$(
            sed -n 's|^[[:space:]]*//[[:space:]]*Output:[[:space:]]*\([^[:space:]]*\)|\1|p' "$SRC" \
                | head -n 1
        )
        if [ -z "$OUTPUT_NAME" ]; then
            OUTPUT_NAME=$(
                sed -n 's|^[[:space:]]*/\*[[:space:]]*Output:[[:space:]]*\([^[:space:]]*\)|\1|p' "$SRC" \
                    | head -n 1
            )
        fi
        if [ -z "$OUTPUT_NAME" ]; then
            OUTPUT_NAME=$(
                sed -n 's|^[[:space:]]*\*[[:space:]]*Output:[[:space:]]*\([^[:space:]]*\)|\1|p' "$SRC" \
                    | head -n 1
            )
        fi
        [ -n "$OUTPUT_NAME" ] || { err "не найден комментарий 'Output:' в $SRC"; exit 7; }
        cd "$TMPDIR"
        if ! "$TOOL" -o "$OUTPUT_NAME" "$SRC_ABS"; then
            err "ошибка компиляции: $SRC"
            exit 7
        fi
        ;;
esac
cp "$TMPDIR/$OUTPUT_NAME" "$SCRIPT_DIR/$OUTPUT_NAME" || { err "не удалось скопировать результат"; exit 9; }
case "$SRC" in
    *.tex) : ;;
    *) chmod +x "$SCRIPT_DIR/$OUTPUT_NAME" 2>/dev/null || true ;;
esac
echo "готово: $SCRIPT_DIR/$OUTPUT_NAME"
exit 0