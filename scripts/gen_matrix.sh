#!/usr/bin/env bash
set -euo pipefail
ROOT="sources/policies"
OUT="matrix/policies.csv"
mkdir -p "$(dirname "$OUT")"
echo "policy_name,category,legacy_path,cel_path,status,parity_notes,owner,tracking_link" > "$OUT"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

# Pass 1: handle categories that have a -cel folder
for celcat in "$ROOT"/*-cel; do
  [ -d "$celcat" ] || continue
  base="$(basename "$celcat" | sed 's/-cel$//')"
  legacy="$ROOT/$base"

  # list policy subdirs
  find "$celcat" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort -u > "$tmpdir/cel.txt"
  if [ -d "$legacy" ]; then
    find "$legacy" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort -u > "$tmpdir/legacy.txt"

    # Both
    comm -12 "$tmpdir/legacy.txt" "$tmpdir/cel.txt" | while read -r name; do
      echo "$name,$base,$legacy/$name,$celcat/$name,Both,,Azeez," >> "$OUT"
    done
    # Legacy only
    comm -23 "$tmpdir/legacy.txt" "$tmpdir/cel.txt" | while read -r name; do
      echo "$name,$base,$legacy/$name, ,Legacy only,,Azeez," >> "$OUT"
    done
    # CEL only
    comm -13 "$tmpdir/legacy.txt" "$tmpdir/cel.txt" | while read -r name; do
      echo "$name,$base, ,$celcat/$name,CEL only,,Azeez," >> "$OUT"
    done
  else
    # No legacy folder at all → everything is CEL only
    while read -r name; do
      [ -z "$name" ] && continue
      echo "$name,$base, ,$celcat/$name,CEL only,,Azeez," >> "$OUT"
    done < "$tmpdir/cel.txt"
  fi
done

# Pass 2: categories that have NO -cel counterpart → Legacy only
for legacy in "$ROOT"/*; do
  [ -d "$legacy" ] || continue
  base="$(basename "$legacy")"
  [[ "$base" == *-cel ]] && continue
  if [ ! -d "$ROOT/${base}-cel" ]; then
    find "$legacy" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort -u | while read -r name; do
      [ -z "$name" ] && continue
      echo "$name,$base,$legacy/$name, ,Legacy only,,Azeez," >> "$OUT"
    done
  fi
done
