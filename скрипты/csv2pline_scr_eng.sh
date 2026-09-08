#!/bin/sh
# Copyleft Efenstor 2025-2026

TEXT_HEIGHT=1.2
TEXT_X_OFF=1
TEXT_Y_OFF=0
CIRCLE_RADIUS=.5

# Help
if [ $# -lt 1 ]; then
  echo "
Convert .csv with point coordinates into .scr file suitable for direct drag and
drop into AutoCAD as a closed polyline

Usage: $0 [options] <input> [output]
Options:
  -t: add point numbers text
  -c: add circles around points
  -n: input file does not include point numbers (number by order)
  -x: X coord goes first (default is the geodetic order: Y X)
  -i <num>: point to ignore, can be specified multiple times, -1 = last point

The input file can contain extra tabs or spaces, newlines in wrong places,
comma instead of dot as decimal separator: as long as the values go in either
triplets or pairs (when -n option is used) it does not matter.
"
  exit
fi

# Parse arguments
optstr="?htcnxi:"
add_text= ; add_circles= ; use_pn=1; swap_xy= ; ign=
while getopts $optstr opt; do
  if [ ! $? -eq 0 ]; then
    exit
  fi
  case "$opt" in
    t ) add_text=1 ;;
    c ) add_circles=1 ;;
    n ) use_pn= ;;
    x ) swap_xy=1 ;;
    i) if [ "$OPTARG" = "-1" ]; then
         ignore_last=1
       else
         ign="$ign""$OPTARG;"
       fi
       ;;
    \?) exit 1 ;;
  esac
done
shift $(expr $OPTIND - 1)

# Prerequisites
dir=$(dirname "$1")
infile=$(basename "$1")
name="${infile%.*}"

# Make output file name
if [ "$2" ]; then
  outfile="$2"
else
  outfile="$name".scr
fi

# Read file
file=$(cat "$1")

# Normalize the file:
# * remove caret returns (Windows standard)
# * replace TABs with spaces
# * replace commas with dots
# * remove extra spaces at the beginning of each line
# * remove extra spaces at the end of each line
# * replace newlines with spaces (cleanest method is to use tr)
# * collapse space sequences
file=$(echo "$file" | sed 's/\r//g; s/\t/ /g; s/,/./g; s/^ //g; s/ $//g; s/\n/ /g' | tr '\n' ' ' | sed 's/  / /g')

# Split into either triplets or pairs
if [ "$use_pn" ]; then
  file=$(echo "$file" | sed -n "s/\([0-9.]*\) \([0-9.]*\) \([0-9.]*\) /\1 \2 \3\n/pg")
else
  file=$(echo "$file" | sed -n "s/\([0-9.]*\) \([0-9.]*\) /\1 \2\n/pg")
fi

# Begin the output
pline="_PLINE "
text=
circles=

# Parse
num=1
pn= ; x= ; y=
while [ -n "$file" ]
do
  i=$(echo "$file" | head -n 1)
  file=$(echo "$file" | tail -n +2)

  # Point number
  if [ "$use_pn" ]; then
    pn=$(echo "$i" | cut -s -d' ' -f1)
  else
    pn=$num
  fi

  # Ignore specified points
  if [ "$ign" ]; then
    if echo "$ign" | grep -e "^$pn;" -e ";$pn;" > /dev/null; then
      echo "Ignoring point $pn"
      num=$(( $num + 1 ))
      continue
    fi
  fi

  # Extract fields
  if [ "$use_pn" ]; then
    y=$(echo "$i" | cut -s -d' ' -f2)
    x=$(echo "$i" | cut -s -d' ' -f3)
  else
    y=$(echo "$i" | cut -s -d' ' -f1)
    x=$(echo "$i" | cut -s -d' ' -f2)
  fi

  # Echo or swap and echo
  if [ ! "$swap_xy" ]; then
    echo "pnum=$pn; Y=$y; X=$x"
  else
    xx=$x; x=$y; y=$xx
    echo "pnum=$pn; X=$x; Y=$y"
  fi

  # Add text
  if [ "$add_text" ]; then
    tx=$(echo "$x + $TEXT_X_OFF" | bc)
    ty=$(echo "$y + $TEXT_Y_OFF" | bc)
    text="$text""_TEXT $tx,$ty $TEXT_HEIGHT 0\r\n$pn\r\n"
  fi

  # Add circle
  if [ "$add_circles" ]; then
    circles="$circles""_CIRCLE $x,$y $CIRCLE_RADIUS\r\n"
  fi

  # Write
  pline="$pline""$x,$y\r\n"

  # Counter inc
  num=$(( $num + 1 ))
done

# Remove last point if needed
if [ "$ignore_last" ]; then
  echo "Ignoring last point ($pn)"
  pline=$(echo "$pline" | head -n-2)
fi

# Close the polyline
pline="$pline""_C\r\n"

# Write to the output file
printf -- "$pline" > "$outfile"

# Add text
if [ "$add_text" ]; then
  printf -- "$text" >> "$outfile"
fi

# Add circles
if [ "$add_circles" ]; then
  printf -- "$circles" >> "$outfile"
fi

echo "Done!"
echo "Don't forget to set OSNAPCOORD 1, otherwise you'll get distortion!"
