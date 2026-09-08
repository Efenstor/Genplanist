#!/bin/sh
# copyleft 2026 Efenstor

# Возможные ключевые слова для промежутков нумерации, см.
# https://www.coherentpdf.com/cpdfmanual.pdf
# раздел "1.3 Input Ranges"

DSTNAME="ПЗУ"  # имя pdf собранного файла
RANGE="2-end"  # промежуток нумерации
FIRST_PAGE=2  # номер первой страницы
DSTDIR="ВЫДАЧА"  # имя директории для сборки


# == не трогайте ничего далее этой строки ==

better_cp() {
  # Case-insensitive batch copy
  if [ ! -d "$2" ]; then
    echo "Директория \"$2\" не существует!"
  else
    find . -maxdepth 1 -type f -iname "$1" -exec cp -v '{}' "$2" \;
  fi
}

cpdf_find() {
  # Case-insensitive find, sort and make the cpdf arguments
  files=$(find . -maxdepth 1 -type f -iname '*.pdf' | sort -f)
  if [ ! "$files" ]; then
    echo "Не найдено ни одного PDF файла!"
    exit
  fi
  pdfs=
  while [ -n "$files" ]; do
    i=$(echo "$files" | head -n 1)
    files=$(echo "$files" | tail -n +2)
    pdfs="$pdfs""-i \"$i\" "
  done
}

# Find cpdf
script_dir=$(dirname "$*")
if which -s cpdf; then
  cpdf=cpdf
elif [ -f "$script_dir"/cpdf ]; then
  cpdf="$script_dir"/cpdf
else
  printf "
Не найдена утилита cpdf!\n
Скачайте https://github.com/coherentgraphics/cpdf-binaries/archive/master.zip
распакуйте, найтите бинарник соответствующий вашему процессору и поместите его
либо в \$PATH, либо в директорию с этим скриптом.
\n"
  exit
fi

# Create the dst dir
if [ ! -d "$DSTDIR" ]; then
  echo "Создаём директорию \"$DSTDIR\"..."
  mkdir "$DSTDIR"
fi

# Make pdf
echo "Собираем \"$DSTNAME.pdf\"..."
cpdf_find
eval \"$cpdf\" -progress -merge-add-bookmarks $pdfs \
  AND -prerotate -range $RANGE -bates-at-range $FIRST_PAGE -add-text \"%Bates\" \
  -topright \"9mm 10.5mm\" -font "Arial" -font-size 11 \
  -o \"$DSTDIR\"/\"$DSTNAME\".pdf; ec=$?
if [ $ec -ne 0 ]; then
  echo "Сборка не удалась! Ошибка $ec"
  exit
fi

# Copy source files
echo "Копируем файлы..."
better_cp '*.dwg' "$DSTDIR"
better_cp '*.doc' "$DSTDIR"
better_cp '*.docx' "$DSTDIR"
better_cp '*.rtf' "$DSTDIR"
better_cp '*.jpg' "$DSTDIR"
better_cp '*.jpeg' "$DSTDIR"
better_cp '*.tif' "$DSTDIR"
better_cp '*.tiff' "$DSTDIR"
better_cp '*.png' "$DSTDIR"

# Done
echo "Готово!"
