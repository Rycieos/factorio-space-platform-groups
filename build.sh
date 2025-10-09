#!/bin/sh

info="$(cat info.json)"
name="${info##*'"name": "'}"
name="${name%%'"'*}"
version="${info##*'"version": "'}"
version="${version%%'"'*}"

dir="${name}_${version}"
mkdir -p "$dir"

cp -r \
  ./changelog.txt \
  ./info.json \
  ./*.lua \
  prototypes \
  scripts \
  locale \
  "$dir/"

zip -r "${dir}.zip" "$dir"

rm -r "$dir/"
