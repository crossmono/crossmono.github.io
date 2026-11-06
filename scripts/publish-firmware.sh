#!/usr/bin/env bash
# Copies one CrossMono release into firmware/<tag>/, points manifest.json (a final release) or
# manifest-rc.json (a release candidate) at it, and removes the firmware folders that neither manifest uses
# now or used before this run. Pages and its CDN cache files for 10 minutes, so a cached old manifest can still
# point at the previous folders; they go on the next run.
#
# Usage, from the site root: scripts/publish-firmware.sh <tag> <dir>
# <dir> holds the release assets crossmono-<tag>-papermono-full.bin, manifest.json,
# crossmono-<tag>-LICENSE.txt (every licence of the image, linked from the page) and SHA256SUMS.
# The publish-firmware workflow downloads them, runs this script, and commits the result.
set -euo pipefail

die() {
  echo "error: $*" >&2
  exit 1
}

[ $# -eq 2 ] || die "usage: scripts/publish-firmware.sh <tag> <dir>"
tag=$1
src=$2

# The firmware's tag rule (scripts/mono/package_release.py in nandanito/crossmono).
tag_re='^[0-9]+\.[0-9]+\.[0-9]+(-rc\.[1-9][0-9]*)?$'
[[ $tag =~ $tag_re ]] || die "not a CrossMono tag: $tag"
[ -f index.html ] || die "run this from the site root"
[ -d firmware ] || die "run this from the site root"

full="crossmono-$tag-papermono-full.bin"
license="crossmono-$tag-LICENSE.txt"
for name in "$full" manifest.json "$license" SHA256SUMS; do
  [ -f "$src/$name" ] || die "missing $src/$name"
done

# SHA256SUMS also lists the OTA image and the ELF, which the site does not need.
sums=$(awk -v a="$full" -v b=manifest.json -v c="$license" '$2 == a || $2 == b || $2 == c' "$src/SHA256SUMS")
[ "$(printf '%s\n' "$sums" | grep -c .)" -eq 3 ] || die "SHA256SUMS must list $full, manifest.json and $license once each"
if command -v sha256sum >/dev/null; then
  sha256=(sha256sum)
else
  sha256=(shasum -a 256)
fi
(cd "$src" && printf '%s\n' "$sums" | "${sha256[@]}" -c -) || die "checksum mismatch"

jq -e --arg tag "$tag" --arg full "$full" '
  .name == "CrossMono" and .version == $tag
  and (.builds | length) == 1 and .builds[0].chipFamily == "ESP32-S3"
  and .builds[0].parts == [{path: $full, offset: 0}]' "$src/manifest.json" >/dev/null ||
  die "manifest.json is not the one-part manifest for $tag"

placeholder='{"name": "CrossMono", "version": "", "builds": []}'
version_of() { jq -r '.version // ""' "$1"; }
base_of() { printf '%s\n' "${1%%-rc.*}"; }
# True when version $1 <= $2. Only for two x.y.z values or two candidates: sort -V puts x.y.z before
# x.y.z-rc.N, the reverse of SemVer, so never pass one of each.
not_after() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n 1)" = "$1" ]; }

stable=$(version_of manifest.json)
candidate=$(version_of manifest-rc.json)
previous_stable=$stable
previous_candidate=$candidate

if [[ $tag == *-rc.* ]]; then
  # A test build must be newer than the stable release, or the page would offer an older version.
  if [ -n "$stable" ] && not_after "$(base_of "$tag")" "$stable"; then
    die "$tag is not newer than the stable release $stable"
  fi
  if [ -n "$candidate" ] && ! not_after "$candidate" "$tag"; then
    echo "::warning::The test build goes back from $candidate to $tag."
  fi
  target=manifest-rc.json
else
  if [ -n "$stable" ] && ! not_after "$stable" "$tag"; then
    echo "::warning::The stable release goes back from $stable to $tag."
  fi
  target=manifest.json
fi

dest="firmware/$tag"
rm -rf "$dest"
mkdir -p "$dest"
cp "$src/$full" "$src/manifest.json" "$src/$license" "$src/SHA256SUMS" "$dest/"

# The part path in the release manifest is relative to it; from the site root it is under $dest.
# Each manifest is written to a temporary file first, so a failed jq leaves the old one in place.
jq --arg path "$dest/$full" '.builds[0].parts[0].path = $path' "$dest/manifest.json" >"$target.tmp"
mv "$target.tmp" "$target"

# A final release replaces its own candidates and older ones; a candidate for a later version stays.
if [ "$target" = manifest.json ] && [ -n "$candidate" ] && not_after "$(base_of "$candidate")" "$tag"; then
  jq -n "$placeholder" >manifest-rc.json.tmp
  mv manifest-rc.json.tmp manifest-rc.json
fi

stable=$(version_of manifest.json)
candidate=$(version_of manifest-rc.json)
# Publishing the same tag again changes no manifest, so it must not retire the previous folders early.
if [ "$stable" = "$previous_stable" ] && [ "$candidate" = "$previous_candidate" ]; then
  echo "stable: ${stable:-none}, test build: ${candidate:-none} (unchanged, nothing pruned)"
  exit 0
fi
for dir in firmware/*/; do
  name=$(basename "$dir")
  [[ $name =~ $tag_re ]] || continue
  case "$name" in
    "$stable" | "$candidate" | "$previous_stable" | "$previous_candidate") ;;
    *)
      echo "removing $dir"
      rm -rf "$dir"
      ;;
  esac
done

echo "stable: ${stable:-none}, test build: ${candidate:-none}"
