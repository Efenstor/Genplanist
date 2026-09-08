#!/bin/sh
# Copyleft Efenstor 2024

sn=$(basename "$0")

if [ $# -lt 1 ]; then
  echo "Калькулятор объёма пирамиды (усечённой и полной)"
  echo "Copyleft Efenstor 2024"
  echo "Использование: $sn <ширина1> <длина1> <высота> [<ширина2> <длина2>]"
  exit
elif [ $# -ne 3 ] && [ $# -ne 5 ]; then
  echo "Не хватает одного или более необходимых параметров"
  exit
fi

if [ $# -eq 3 ]; then
  a=0; b=0
else
  a=$4; b=$5
fi

A=$1; B=$2; h=$3
echo "( $A * $b + $a * $B + 2 * ( $a * $b + $A * $B ) ) / 6 * $h" | bc -l

