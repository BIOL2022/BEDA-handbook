#!/usr/bin/env bash

set -euo pipefail

source_pdf="${1:-_book/Biology-Experimental-Design-and-Analysis.pdf}"
destination_pdf="${2:-_site/downloads/BIOL2022-unit-handbook.pdf}"

if [[ ! -s "$source_pdf" ]]; then
  echo "Expected a non-empty handbook PDF at $source_pdf" >&2
  exit 1
fi

mkdir -p "$(dirname "$destination_pdf")"
cp "$source_pdf" "$destination_pdf"

if [[ ! -s "$destination_pdf" ]]; then
  echo "Failed to stage the handbook PDF at $destination_pdf" >&2
  exit 1
fi
