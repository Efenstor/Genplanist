#!/bin/sh
# Agreement Maker
# Made by Efenstor, copyleft 2026
version=1.1a

# Template files
template_prepay="шаблон_договора_с_авансом.fodt"
template_noprepay="шаблон_договора_без_аванса.fodt"

# Replaceable strings
r_num="###НОМЕР###"
r_date="###ДАТА###"
r_job="###РАБОТЫ###"
r_dline="###СРОК###"
r_price="###СТОИМОСТЬ###"
r_prepayp="###АВАНСПР###"
r_prepay="###АВАНС###"
r_finalpayp="###ОКОНЧПР###"
r_finalpay="###ОКОНЧ###"
r_obj_text=" по объекту "
r_addr_text=", находящемуся по адресу: "

# Questions and defaults
q_num_title="Номер договора"
q_num_def=""
q_date_title="Дата договора (в формате $(date -I))"
q_date_def=""
q_job_title="Вид работ"
q_job_def="работы по разработке раздела ПЗУ проектной документации"
q_obj_title="Объект (необязательно)"
q_obj_def=""
q_addr_title="Адрес объекта (необязательно)"
q_addr_def=""
q_dline_title="Срок выполнения работ (необязательно, в формате $(date -I))"
q_dline_def=""
q_price_title="Стоимость работ"
q_price_def=""
q_prepayp_title="Аванс (процент)"
q_prepayp_def="0"

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
optstr="?hxdp:n:f"
savedata=1
usecurdate=0
fodt=0
while getopts $optstr opt; do
  case "$opt" in
    x) savedata=0 ;;
    d) usecurdate=1 ;;
    p) template_prepay="$OPTARG" ;;
    n) template_noprepay="$OPTARG" ;;
    f) fodt=1 ;;
    :) echo "Missing argument for -$OPTARG" >&2
       exit 1
       ;;
  esac
done
shift $((OPTIND - 1))

# Help
if [ $# -lt 1 ]; then
  echo "
СОСТАВИТЕЛЬ ДОГОВОРОВ v$version
Использование: make_agreement.sh [опции] <выходной_файл> [файл/каталог_данных]

Аргументы:
  выходной_файл: выходной файл, может быть без расширения (по умолчанию .docx)
  файл/каталог_данных: файл данных для заполнения полей или каталог с таковым
    файлом (файл с расширением .dat). Если в каталоге присутствует несколько
    файлов с расширением .dat, то будет использован первый по алфавиту.
    (по умолчанию: каталог выходного файла)

Опции:
  -x: не сохранять вводимые данные в файл
  -d: использовать текущую дату вместо данных из файла
  -p <файл>: файл шаблона раздела оплаты с авансом
  -n <файл>: файл шаблона раздела оплаты без аванса
  -f: использовать выходной формат .fodt (не конвертировать в .docx)
  
Файлы шаблонов по умолчанию:
  Договор с авансом: \"$template_prepay\"
  Договор без аванса: \"$template_noprepay\"
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
if [ ! -f "$template_prepay" ] && [ ! -f "$template_noprepay" ]; then
  echo "Не найден ни один файл шаблона"
  exit 1
fi

# Data file
datafile=
if [ "$2" ]; then
  if [ -d "$2" ]; then
    # Existing dir
    dname="$2"
  else
    # Existing or yet non-existing file
    datafile="$2"
  fi
else
  # Use the destination file dir
  dname=$(dirname "$1")
fi
if [ ! -d "$dname" ]; then
  echo "Каталог \"$dname\" не существует"
  exit 1
fi
if [ ! "$datafile" ]; then
  # Try to find an existing data file
  datafile=$(find "$dname" -maxdepth 1 -type f -iname "*.dat" | sort -f | head -n 1)
  if [ ! "$datafile" ]; then
    # Prepare new file name
    dname=$(dirname "$1")
    fname=$(basename "$1")
    datafile="$dname"/"${fname%.*}".dat
  fi
fi

# Read data file (if exists) and replace the defaults
if [ -f "$datafile" ]; then
  readval "num" "$datafile" q_num_def
  if [ $usecurdate -eq 0 ]; then
    readval "date" "$datafile" q_date_def
  fi
  readval "job" "$datafile" q_job_def
  readval "obj" "$datafile" q_obj_def
  readval "addr" "$datafile" q_addr_def
  if [ $usecurdate -eq 0 ]; then
    readval "dline" "$datafile" q_dline_def
  fi
  readval "price" "$datafile" q_price_def
  readval "prepayp" "$datafile" q_prepayp_def
fi

# Questions
question "$q_num_title" "$q_num_def" 0 0 a_num
if [ $savedata -ne 0 ]; then saveval "num" "$a_num" "$datafile"; fi
if [ ! "$q_date_def" ]; then
  q_date_def=$(date -I'date')
fi
question "$q_date_title" "$q_date_def" 0 0 a_date
if [ $savedata -ne 0 ]; then saveval "date" "$a_date" "$datafile"; fi
question "$q_job_title" "$q_job_def" 0 0 a_job
if [ $savedata -ne 0 ]; then saveval "job" "$a_job" "$datafile"; fi
question "$q_obj_title" "$q_obj_def" 0 1 a_obj
if [ $savedata -ne 0 ]; then saveval "obj" "$a_obj" "$datafile"; fi
question "$q_addr_title" "$q_addr_def" 0 1 a_addr
if [ $savedata -ne 0 ]; then saveval "addr" "$a_addr" "$datafile"; fi
if [ ! "$q_dline_def" ]; then
  q_dline_def=$(date --date="$a_date+1 month" -I'date')
fi
question "$q_dline_title" "$q_dline_def" 0 1 a_dline
if [ $savedata -ne 0 ]; then saveval "dline" "$a_dline" "$datafile"; fi
question "$q_price_title" "$q_price_def" 1 0 a_price
if [ $savedata -ne 0 ]; then saveval "price" "$a_price" "$datafile"; fi
question "$q_prepayp_title" "$q_prepayp_def" 1 0 a_prepayp
if [ $savedata -ne 0 ]; then saveval "prepayp" "$a_prepayp" "$datafile"; fi

# Prepare the output file name
dname=$(dirname "$1")
fname=$(basename "$1")
if [ $fodt -eq 0 ]; then
  outfile="$dname"/"${fname%.*}".docx
else
  outfile="$dname"/"${fname%.*}".fodt
fi

# Which template to use
if [ "$a_prepayp" -gt 0 ]; then
  template="$template_prepay"
else
  template="$template_noprepay"
fi
if [ ! -f "$template" ]; then
  echo "Не найден файл шаблона \"$template\""
  exit 1
fi

# Try to extract the style tag from the template
stag=$(sed -n "s/.*\(<text:span.*>\)$r_job.*/\1/p" "$template")
if [ "$stag" ]; then
  stagcl="</text:span>"
else
  stagcl=
fi

# Prepare values
a_jobfull="$stag""$a_job""$stagcl"
if [ "$a_obj" ]; then
  a_jobfull="$a_jobfull""$r_obj_text""$stag"«"$a_obj"»"$stagcl"
fi
if [ "$a_addr" ]; then
  a_jobfull="$a_jobfull""$r_addr_text""$stag""$a_addr""$stagcl"
fi
a_jobfull="$a_jobfull".
a_price=$(echo "$a_price" | sed "s/ //;s/,/./")  # rectify
a_prepay=$(echo "$a_price * ($a_prepayp/100)" | bc -l)
a_prepay=$(echo "($a_prepay + .5) / 1" | bc)  # make integer
a_finalpayp=$(echo "100 - $a_prepayp" | bc)
a_finalpay=$(echo "$a_price - $a_prepay" | bc)

# Generate spellouts
spelloutprice "$a_price" 0 a_price_spellout
spelloutprice "$a_prepay" 0 a_prepay_spellout
spelloutprice "$a_finalpay" 0 a_finalpay_spellout
a_date_spellout=$(date --date "$a_date" +«%-d»\ %B\ %Y\ г.)
if [ "$a_dline" ]; then
  a_dline_spellout=$(date --date "$a_dline" +«%-d»\ %B\ %Y\ г.)
fi

# Generate grouped versions
groupnumbers "$a_price" 0 a_price_gr
groupnumbers "$a_prepay" 0 a_prepay_gr
groupnumbers "$a_finalpay" 0 a_finalpay_gr

# Create the temporary files
tmpfile=$(mktemp --suffix=.fodt)
tmpdir=$(dirname "$tmpfile")
if [ $? -ne 0 ]; then
  echo "Не получается создать временный файл $tmpfile"
  exit 1
fi
cp -f "$template" "$tmpfile"

# Replace strings in the temporary files
replace "$r_num" "$a_num" "$tmpfile"
replace "$r_date" "$a_date_spellout" "$tmpfile"
if [ "$stag" ]; then
  rj=$(sed -n "s|.*\(.*<text:span.*###РАБОТЫ###.*</text:span>\).*|\1|p" "$template")
  replace "$rj" "$a_jobfull" "$tmpfile"
else
  replace "$r_job" "$a_jobfull" "$tmpfile"
fi
if [ "$a_dline" ]; then
  replace "$r_dline" "$a_dline_spellout" "$tmpfile"
fi
replace "$r_price" "$a_price_gr рублей ($a_price_spellout)" "$tmpfile"
if [ "$a_prepayp" -gt 0 ]; then
  replace "$r_prepayp" "$a_prepayp%" "$tmpfile"
  replace "$r_prepay" "$a_prepay_gr рублей ($a_prepay_spellout)" "$tmpfile"
fi
replace "$r_finalpayp" "$a_finalpayp%" "$tmpfile"
replace "$r_finalpay" "$a_finalpay_gr рублей ($a_finalpay_spellout)" "$tmpfile"

# Convert to DOCX
if [ $fodt -eq 0 ]; then
  tmpdocx="${tmpfile%.*}".docx
  libreoffice --headless --convert-to docx --outdir "$tmpdir" "$tmpfile"
  mv "$tmpdocx" "$outfile"
else
  cp "$tmpfile" "$outfile"
fi
if [ $? -ne 0 ]; then
  echo "Не удалось переместить файл \"$tmpfile\" в \"$outfile\""
fi

# Delete the temporary file
rm "$tmpfile"

