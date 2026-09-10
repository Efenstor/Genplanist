#!/bin/sh
# Bill Maker
# Made by Efenstor, copyleft 2026
version=1.0b

# Template files
template="шаблон_счёта.fods"

# Replaceable strings
r_billnum="###НОМЕРСЧЁТА###"
r_billdate="###ДАТАСЧЁТА###"
r_num="###НОМЕР###"
r_job="###РАБОТЫ###"
r_price="###СТОИМОСТЬ###"
r_price_spellout="###СТОИМОСТЬПР###"
r_obj_text=" по объекту "
r_addr_text=", находящемуся по адресу: "

# Questions and defaults
q_billnum_title="Номер счёта (без номера договора)"
q_billnum_def=""
q_billdate_title="Дата счёта (в формате $(date -I))"
q_billdate_def=""
q_num_title="Номер договора (необязательно)"
q_num_def=""
q_job_title="Вид работ"
q_job_def="Работы по разработке раздела ПЗУ проектной документации"
q_obj_title="Объект (необязательно)"
q_obj_def=""
q_addr_title="Адрес объекта (необязательно)"
q_addr_def=""
q_price_title="Стоимость"
q_price_def=""

# System
system_required="spellout whiptail"
spellout="spellout"

# FUNCTIONS

# Syntax: question "title" "default" type optional "return_var"
#   type: 0 - string, 1 - number
#   optional: 0 - no, 1 - yes
question() {
  while true; do
    ans=$(whiptail --inputbox "$1" 8 78 "$2" 3>&1 1>&2 2>&3)
    if [ $? -gt 0 ]; then
      exit 1
    fi
    if [ $3 -eq 1 ] && echo "$ans" | grep "[^0-9\.,]" > /dev/null; then
      # Only numbers are accepted
      echo "Значение должно быть только числом!"
      echo "(нажмите Enter, чтобы повторить ввод)"
      read _
      continue
    fi
    if [ $4 -eq 0 ] && [ ! "$ans" ]; then
      # No empty strings allowed
      echo "Нужно ввести какое-то значение!"
      echo "(нажмите Enter, чтобы повторить ввод)"
      read _
      continue
    fi
    break
  done
  eval "$5=\"\$ans\""
}

replace() {
  if ! sed -i "s|$1|$2|" "$3"; then
    echo "В шаблоне отсутствует строка $1"
  fi
}

# Syntax: saveval "name" "value" "file"
saveval() {
  if [ ! -f "$3" ]; then
    # Create new file
    touch "$3"
  fi
  if grep "^$1=" "$3" > /dev/null; then
    # Replace existing value
    sed -i "s/^$1=.*$/$1=$2/" "$3"
  else
    # Add new value
    echo "$1=$2" >> "$3"
  fi
}

# Syntax: readval "name" "file" "return_var"
readval() {
  ret=$(sed -n "s/^$1=\(.*\)$/\1/p" "$2")
  if [ "$ret" ]; then
    eval "$3=\"\$ret\""
  fi
}

# Syntax: groupnumbers "value" add_zeroes "return_var"
#   add_zeroes: 0 - no, 1 - yes
groupnumbers() {
  if [ $2 -eq 1 ]; then
    if echo "$1" | grep -q "\.0*" || \
        echo "$1" | grep -q "\.$" || \
        ! echo "$1" | grep -q "\."; then
      val="$1"".00"
    fi
  else
    val="$1"
  fi
  int=$(echo "$val" | sed -n 's|\([0-9]*\).*|\1|p')
  frac=$(echo "$val" | sed -n 's|.*[^0-9]\([0-9]*\)|\1|p')
  intgr=$(echo "$int" | rev | sed 's/.../& /g' | rev | sed 's/ *$//')
  if [ "$frac" ]; then
    eval "$3=\"\$intgr\",\"$frac\""
  else
    eval "$3=\"\$intgr\""
  fi
}

# Syntax: spelloutprice "price" add_zero_kopeks "return_var"
#   add_zero_kopeks: 0 - no, 1 - yes
spelloutprice() {
  ret=$($spellout -l ru-RU -p RUB "$1")
  if [ $2 -eq 1 ]; then
    if echo "$1" | grep -q "\.0*" || \
        echo "$1" | grep -q "\.$" || \
        ! echo "$1" | grep -q "\."; then
      ret="$ret"" ноль копеек"
    fi
  fi
  eval "$3=\"\$ret\""
}

findpkg() {
  if which "apt-file" > /dev/null; then
    # Debian-based system
    pkg=$(apt-file search "$1" | grep /bin/"$1"$ | sed "s/: .*//" | head -n1)
  elif which "pacman" > /dev/null; then
    # Arch-based system
    pkg=$(pacman -F "$1" | grep -B1 /bin/"$1"$ | head -n1 | sed "s/ [0-9].*$//" | sed "s/.*\///")
  fi
  if [ "$pkg" ]; then
    printf "Отсутствующая программа найдена в пакете \"$pkg\". Пожалуйста установите.\n"
  else
    printf "Отсутствующая программа не найдена ни в одном пакете.\n"
  fi
}

# MAIN

# Parse options
optstr="?hxt:f"
savedata=1
fods=0
while getopts $optstr opt; do
  case "$opt" in
    x) savedata=0 ;;
    t) template="$OPTARG" ;;
    f) fods=1 ;;
    :) echo "Missing argument for -$OPTARG" >&2
       exit 1
       ;;
  esac
done
shift $((OPTIND - 1))

# Help
if [ $# -lt 1 ]; then
  echo "
СОСТАВИТЕЛЬ СЧЕТОВ v$version
Использование: make_bill.sh [опции] <выходной_файл> [файл/каталог_данных]

Аргументы:
  выходной_файл: выходной файл, может быть без расширения (по умолчанию .xlsx)
  файл/каталог_данных: файл данных для заполнения полей или каталог с таковым
    файлом (файл с расширением .dat). Если в каталоге присутствует несколько
    файлов с расширением .dat, то будет использован первый по алфавиту.
    (по умолчанию: каталог выходного файла)

Опции:
  -x: не сохранять вводимые данные в файл (только номер счёта)
  -t <файл>: файл шаблона (по умолчанию: \"$template\")
  -f: использовать выходной формат .fods (не конвертировать в .xlsx)
" 
  exit
fi

# Check for the system requirements
for i in $system_required
do
  if [ ! $(which "$i") ]; then
    # Test for Debian-specific paths
    if [ -f "/usr/lib/libnumbertext/spellout" ]; then
      spellout="/usr/lib/libnumbertext/spellout"
    else
      printf "Программа \"$i\" не установлена на вашей системе.\n"
      findpkg "$i"
      exit 1
    fi
  fi
done

# Preliminary checks
if [ ! -f "$template" ]; then
  echo "Не найден файл шаблона \"$template\""
  exit 1
fi

# Data file
datafile=
if [ "$2" ]; then
  if [ -d "$2" ]; then
    dname="$2"
  elif [ -f "$2" ]; then
    datafile="$2"
  else
    echo "Указанный файл/каталог данных не является файлом или каталогом"
    exit 1
  fi
else
  dname=$(dirname "$1")
fi
if [ ! -d "$dname" ]; then
  echo "Каталог \"$dname\" не существует"
  exit 1
fi
if [ ! "$datafile" ]; then
  datafile=$(find "$dname" -maxdepth 1 -type f -iname "*.dat" | sort -f | head -n 1)
fi

# Read data file (if exists) and replace the defaults
if [ -f "$datafile" ]; then
  readval "billnum" "$datafile" q_billnum_def
  readval "billdate" "$datafile" q_billdate_def
  readval "num" "$datafile" q_num_def
  readval "job" "$datafile" q_job_def
  readval "obj" "$datafile" q_obj_def
  readval "addr" "$datafile" q_addr_def
  readval "price" "$datafile" q_price_def
fi

# Questions
question "$q_billnum_title" "$q_billnum_def" 0 0 a_billnum
if [ $savedata -ne 0 ]; then saveval "billnum" "$a_billnum" "$datafile"; fi
if [ ! "$q_billdate_def" ]; then
  q_billdate_def=$(date -I'date')
fi
question "$q_billdate_title" "$q_billdate_def" 0 0 a_billdate
question "$q_num_title" "$q_num_def" 0 1 a_num
question "$q_job_title" "$q_job_def" 0 0 a_job
question "$q_obj_title" "$q_obj_def" 0 1 a_obj
question "$q_addr_title" "$q_addr_def" 0 1 a_addr
question "$q_price_title" "$q_price_def" 1 0 a_price

# Prepare the output file name
dname=$(dirname "$1")
fname=$(basename "$1")
if [ $fods -eq 0 ]; then
  outfile="$dname"/"${fname%.*}".xlsx
else
  outfile="$dname"/"${fname%.*}".fods
fi

# Try to extract the style tag from the template
stag=$(sed -n "s/.*\(<text:span.*>\)$r_job.*/\1/p" "$template")
if [ "$stag" ]; then
  stagcl="</text:span>"
else
  stagcl=
fi

# Prepare values
a_jobfull="$stag"$(echo "$a_job" | sed 's/^\(.\)/\u\1/')"$stagcl"
if [ "$a_obj" ]; then
  a_jobfull="$a_jobfull""$r_obj_text""$stag"«"$a_obj"»"$stagcl"
fi
if [ "$a_addr" ]; then
  a_jobfull="$a_jobfull""$r_addr_text""$stag""$a_addr""$stagcl"
fi
a_jobfull="$a_jobfull".
if [ "$a_num" ]; then
  a_billnum="$a_billnum"-"$a_num"
fi
a_price=$(echo "$a_price" | sed "s/ //;s/,/./")  # rectify

# Generate spellouts
a_billdate_spellout=$(date --date "$a_billdate" +«%-d»\ %B\ %Y\ г.)
spelloutprice "$a_price" 1 a_price_spellout
a_price_spellout=$(echo "$a_price_spellout" | sed 's/^\(.\)/\u\1/')

# Generate grouped versions
groupnumbers "$a_price" 1 a_price_gr

# Create the temporary files
tmpfile=$(mktemp --suffix=.fods)
tmpdir=$(dirname "$tmpfile")
if [ $? -ne 0 ]; then
  echo "Не получается создать временный файл $tmpfile"
  exit 1
fi
cp -f "$template" "$tmpfile"

# Replace strings in the temporary files
replace "$r_billnum" "$a_billnum" "$tmpfile"
replace "$r_billdate" "$a_billdate_spellout" "$tmpfile"
if [ "$stag" ]; then
  rj=$(sed -n "s|.*\(.*<text:span.*###РАБОТЫ###.*</text:span>\).*|\1|p" "$template")
  replace "$rj" "$a_jobfull" "$tmpfile"
else
  replace "$r_job" "$a_jobfull" "$tmpfile"
fi
replace "$r_price" "$a_price_gr" "$tmpfile"
replace "$r_price_spellout" "$a_price_spellout" "$tmpfile"

# Convert to XLSX
if [ $fods -eq 0 ]; then
  tmpxlsx="${tmpfile%.*}".xlsx
  libreoffice --headless --convert-to xlsx --outdir "$tmpdir" "$tmpfile"
  mv "$tmpxlsx" "$outfile"
else
  cp "$tmpfile" "$outfile"
fi
if [ $? -ne 0 ]; then
  echo "Не удалось переместить файл \"$tmpfile\" в \"$outfile\""
fi

# Delete the temporary file
rm "$tmpfile"

