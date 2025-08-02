#!/bin/bash
set -e
mkdir -p copyright

tmp=$(mktemp -d)
function cleanup () {
  rm -rf "$tmp"
}
trap cleanup EXIT

# Docs
echo "Compiling documentation deposit..."
docs="$tmp/docs"
mkdir -p "$docs"

# ./README.md
echo "README.md"
PDF_FLAGS="--pdf-engine=xelatex"
pandoc $PDF_FLAGS -o "$tmp/docs/00000.pdf" README.md

# ./docs
counter=0
for md in docs/*.md; do
  echo "$md"
  counter=$((counter+1))
  printf -v padded "%05d" $counter
  pandoc $PDF_FLAGS -o "$docs/$padded.pdf" "$md"
done

pdftk $docs/*.pdf cat output copyright/documentation-deposit.pdf
echo "copyright/documentation-deposit.pdf"

# Code
echo "Compiling code deposit..."
code="$tmp/code"
mkdir -p "$code"
files=$(git ls-files app script | grep -E "\\.(js|rb)$")
sample=15
first=$(head -n "$sample" <<< "$files")
last=$(tail -n "$sample" <<< "$files")

unoconv --listener &

function process_code () {
  echo "$1"
  counter=$((counter+1))
  printf -v padded "%05d" $counter
  printf "%s\\n\\n" "$1" > "$code/$padded.txt"
  cat "$1" >> "$code/$padded.txt"
  unoconv -o "$code/$padded.pdf" "$code/$padded.txt"
}

counter=0
while IFS= read -r file; do
  process_code "$file"
done <<< "$first"
while IFS= read -r file; do
  process_code "$file"
done <<< "$last"

pdftk $code/*.pdf cat output $code/code.pdf
# first 25 pages and last 25 pages
pdftk $code/code.pdf cat 1-25 r25-end output copyright/code-deposit.pdf
echo "copyright/code-deposit.pdf"
