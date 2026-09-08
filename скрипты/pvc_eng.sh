#!/bin/sh
# Copyleft Efenstor 2024

sn=$(basename "$0")

if [ $# -lt 1 ]; then
  echo "Pyramid Volume Calculator (truncated and full)"
  echo "Copyleft Efenstor 2024"
  echo "Usage: $sn <width1> <length1> <height> [<width2> <length2>]"
  exit
elif [ $# -ne 3 ] && [ $# -ne 5 ]; then
  echo "One or more parameters missing"
  exit
fi

if [ $# -eq 3 ]; then
  a=0; b=0
else
  a=$4; b=$5
fi

A=$1; B=$2; h=$3
echo "( $A * $b + $a * $B + 2 * ( $a * $b + $A * $B ) ) / 6 * $h" | bc -l

