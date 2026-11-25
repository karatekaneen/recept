#!/usr/bin/env bash
# Gör om innehall/ till Hugo-innehåll i .build/content/.
#
#  - .cook-filer tolkas med CookCLI och blir sidor med receptet som JSON.
#  - Kapitelmappar får sin siffra borttagen ("01-brod-och-bakat" → "brod-och-bakat").
#  - Bilder och korta historier kopplas till receptet via filnamnet.
#  - Bygget kontrollerar id, översättningar och receptlänkar i artiklar.
#
# Kräver: cook (CookCLI) och jq.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/innehall"
OUT="$ROOT/.build/content"
LANGS=(sv en)
MAIN_LANG=sv

COOK="${COOK:-cook}"
command -v "$COOK" >/dev/null || { echo "Hittar inte CookCLI ($COOK). Se README." >&2; exit 1; }
command -v jq >/dev/null || { echo "Hittar inte jq. Se README." >&2; exit 1; }

rm -rf "$ROOT/.build"
mkdir -p "$OUT"
TMP="$ROOT/.build/tmp"
mkdir -p "$TMP"
: > "$TMP/labels.tsv"

# Mappnamn för etikettsidor (t.ex. innehall/sv/restauranger/operakallaren/_index.md)
# mappas till Hugos taxonominamn.
taxonomy_dir() {
  case "$1" in
    restauranger|restaurants) echo restaurang ;;
    forfattare|authors)       echo forfattare ;;
    kategorier|categories)    echo kategori ;;
    taggar|tags)              echo tags ;;
    *)                        echo "$1" ;;
  esac
}

# Tar bort sifferprefix från varje mappnamn i en relativ sökväg.
strip_prefixes() {
  local IFS=/ part out=()
  for part in $1; do out+=("$(sed -E 's/^[0-9]+[-_ ]+//' <<<"$part")"); done
  (IFS=/; echo "${out[*]}")
}

# Kapitelordning från sifferprefix (01-… → 1).
prefix_weight() {
  local n
  n="$(sed -nE 's/^0*([0-9]+)[-_ ].*/\1/p' <<<"$1")"
  echo "${n:-0}"
}

find_image() {
  local base="$1" ext
  for ext in jpg jpeg png webp JPG JPEG PNG WEBP; do
    [[ -f "$base.$ext" ]] && { echo "$base.$ext"; return; }
  done
}

errors=0
declare -A IMAGE_BY_ID=()   # id → bild från huvudspråket
declare -A IDS=()           # "sv:id" → fil
declare -A RECIPE_TITLE=()  # "sv:id" → titel

for lang in "${LANGS[@]}"; do
  [[ -d "$SRC/$lang" ]] || continue
  dest="$OUT/$lang"
  mkdir -p "$dest"

  # 1. Markdown-sidor (startsida, kapitel, artiklar, fristående sidor, etikettsidor).
  while IFS= read -r -d '' f; do
    rel="${f#"$SRC/$lang/"}"
    dir="$(dirname "$rel")"; name="$(basename "$rel")"
    # En .md bredvid en .cook är receptets korta historia, inte en egen sida.
    [[ -f "${f%.md}.cook" ]] && continue
    top="${rel%%/*}"
    if [[ "$dir" != "." && "$top" != recept && "$top" != blogg ]]; then
      dir="$(taxonomy_dir "$top")${dir#"$top"}"
    fi
    dir="$(strip_prefixes "$dir")"
    mkdir -p "$dest/$dir"
    target="$dest/$dir/$name"
    if [[ "$name" == _index.md && "$top" == recept && "$(dirname "$rel")" != recept ]]; then
      # Kapitel: ordning från mappens siffra.
      w="$(prefix_weight "$(basename "$(dirname "$rel")")")"
      awk -v w="$w" 'NR==1 && /^---$/ {print; print "weight: " w; next} {print}' "$f" > "$target"
    else
      cp "$f" "$target"
    fi
  done < <(find "$SRC/$lang" -type f -name '*.md' -print0)

  # Bilder och andra filer i artikelmappar följer med.
  while IFS= read -r -d '' f; do
    rel="${f#"$SRC/$lang/"}"
    [[ "$rel" == recept/* ]] && continue
    d="$(strip_prefixes "$(dirname "$rel")")"
    mkdir -p "$dest/$d"; cp "$f" "$dest/$d/"
  done < <(find "$SRC/$lang" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.svg' \) -print0)

  # 2. Recept.
  while IFS= read -r -d '' f; do
    rel="${f#"$SRC/$lang/"}"
    base="${f%.cook}"
    chapter="$(strip_prefixes "$(dirname "$rel")")"
    json="$TMP/recipe.json"
    if ! "$COOK" recipe "$f" -f json > "$json" 2> "$TMP/cook.err"; then
      echo "FEL i $rel:" >&2; cat "$TMP/cook.err" >&2
      errors=$((errors + 1)); continue
    fi
    id="$(jq -r '.metadata.map.id // empty' "$json")"
    title="$(jq -r '.metadata.map.title // empty' "$json")"
    if [[ -z "$id" || -z "$title" ]]; then
      echo "FEL i $rel: fälten 'title' och 'id' är obligatoriska." >&2
      errors=$((errors + 1)); continue
    fi
    if [[ -n "${IDS[$lang:$id]:-}" ]]; then
      echo "FEL i $rel: id '$id' används redan av ${IDS[$lang:$id]}." >&2
      errors=$((errors + 1)); continue
    fi
    IDS[$lang:$id]="$rel"
    RECIPE_TITLE[$lang:$id]="$title"

    bundle="$dest/$chapter/$id"
    mkdir -p "$bundle"

    img="$(find_image "$base")"
    if [[ -n "$img" && "$lang" == "$MAIN_LANG" ]]; then IMAGE_BY_ID[$id]="$img"; fi
    [[ -z "$img" ]] && img="${IMAGE_BY_ID[$id]:-}"
    image_name=""
    if [[ -n "$img" ]]; then
      image_name="bild.${img##*.}"; image_name="${image_name,,}"
      cp "$img" "$bundle/$image_name"
    fi

    # Sidan: JSON-frontmatter (Hugo läser det direkt) + kort historia som brödtext.
    jq --arg id "$id" --arg image "$image_name" --arg src "$rel" '
      (.metadata.map) as $m
      | def list($k): ($m[$k] // []) | if type == "array" then . else [.] end | map(tostring);
      {
        title: $m.title,
        id: $id,
        translationKey: ("recept-" + $id),
        description: ($m.description // ""),
        date: ($m.date // null),
        slug: ($m.slug // null),
        tags: list("tags"),
        restaurang: list("restaurang"),
        forfattare: list("forfattare"),
        kategori: list("kategori"),
        params: {
          kind: "recipe",
          image: (if $image == "" then null else $image end),
          servings: ($m.servings // null),
          time: ($m.time // null),
          source: $src,
          recipe: .
        }
      } | with_entries(select(.value != null))
    ' "$json" > "$bundle/index.md"
    jq -r --arg l "$lang" '.metadata.map as $m | ["tags","restaurang","forfattare","kategori"][] as $k
      | ($m[$k] // []) | (if type == "array" then .[] else . end) | [$l, $k, tostring] | @tsv' "$json" >> "$TMP/labels.tsv"
    if [[ -f "$base.md" ]]; then
      printf '\n' >> "$bundle/index.md"
      cat "$base.md" >> "$bundle/index.md"
    fi
  done < <(find "$SRC/$lang" -type f -name '*.cook' -print0 | sort -z)
done

# 3. Kategorier: koppla ihop språken via ordlistan i i18n/en.toml.
#    Rader som  "kategori:Förrätt" = "Starter"  ger sidor med samma translationKey.
if [[ -f "$ROOT/i18n/en.toml" ]]; then
  while IFS=$'\t' read -r sv en; do
    for pair in "sv:$sv" "en:$en"; do
      l="${pair%%:*}"; name="${pair#*:}"
      [[ -d "$OUT/$l" ]] || continue
      slug="$(jq -rn --arg s "$name" '$s | ascii_downcase')"
      slug="$(iconv -f utf-8 -t ascii//TRANSLIT <<<"$slug" 2>/dev/null || echo "$slug")"
      slug="$(sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g' <<<"$slug")"
      d="$OUT/$l/kategori/$slug"
      if [[ -f "$d/_index.md" ]]; then
        if ! grep -q '^translationKey:' "$d/_index.md"; then
          awk -v k="kategori-$sv" 'NR==1 && /^---$/ {print; print "translationKey: \"" k "\""; next} {print}' "$d/_index.md" > "$d/_index.tmp" && mv "$d/_index.tmp" "$d/_index.md"
        fi
      else
        mkdir -p "$d"
        printf -- '---\ntitle: "%s"\ntranslationKey: "kategori-%s"\n---\n' "$name" "$sv" > "$d/_index.md"
      fi
    done
  done < <(sed -nE 's/^"kategori:([^"]+)"[[:space:]]*=[[:space:]]*"([^"]+)".*/\1\t\2/p' "$ROOT/i18n/en.toml")
fi

# 4. Kontroller (information, inte fel).
echo "== Recept som saknar översättning =="
missing=0
for key in "${!IDS[@]}"; do
  l="${key%%:*}"; id="${key#*:}"
  for other in "${LANGS[@]}"; do
    [[ "$other" == "$l" || ! -d "$SRC/$other" ]] && continue
    if [[ -z "${IDS[$other:$id]:-}" ]]; then
      echo "  $id ($l) saknas på $other"; missing=$((missing + 1))
    fi
  done
done | sort
echo

echo "== Artiklar som pekar på recept som inte finns =="
for lang in "${LANGS[@]}"; do
  [[ -d "$OUT/$lang/blogg" ]] || continue
  while IFS= read -r -d '' f; do
    refs="$(awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {exit} fm && /^recept:/ {sub(/^recept:[[:space:]]*/, ""); print}' "$f" | tr -d '[]' | tr ',' '\n' | sed 's/^ *//; s/ *$//; s/^"//; s/"$//')"
    refs+=$'\n'"$(grep -oE '\{\{<[[:space:]]*recept[[:space:]]+[^ >]+' "$f" | awk '{print $NF}' | tr -d '"' || true)"
    while IFS= read -r r; do
      [[ -z "$r" ]] && continue
      [[ -n "${IDS[$lang:$r]:-}" ]] || echo "  VARNING: ${f#"$OUT/"} pekar på '$r' som inte finns på $lang"
    done <<<"$refs"
  done < <(find "$OUT/$lang/blogg" -type f -name '*.md' ! -name '_index.md' -print0)
done
echo

echo "== Etiketter som bara används en gång (kanske stavfel?) =="
for lang in "${LANGS[@]}"; do
  [[ -d "$OUT/$lang" ]] || continue
  for tax in tags restaurang forfattare kategori; do
    {
      awk -F'\t' -v l="$lang" -v t="$tax" '$1==l && $2==t {print $3}' "$TMP/labels.tsv"
      find "$OUT/$lang" -name '*.md' ! -name '_index.md' ! -path '*/recept/*' -print0 | xargs -0 -r awk -v k="$tax" 'FNR==1 {fm=0} FNR==1 && /^---$/ {fm=1; next} fm && /^---$/ {fm=0; nextfile} fm && $0 ~ "^"k":" {sub("^"k":[[:space:]]*", ""); gsub(/[\[\]"]/, ""); n=split($0, a, ","); for (i=1;i<=n;i++) {gsub(/^ +| +$/, "", a[i]); if (a[i]!="") print a[i]}}'
    } | sort | uniq -c | awk -v l="$lang" -v t="$tax" '$1==1 {sub(/^ *1 /, ""); print "  " l "/" t ": " $0}'
  done
done
echo

if (( errors > 0 )); then
  echo "Bygget stoppades: $errors fel i recepten (se ovan)." >&2
  exit 1
fi
echo "Klart: innehållet ligger i .build/content/"
