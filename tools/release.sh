#!/bin/bash
# Cut a release: stamp the version into every file that carries it, show the
# diff, and on confirmation commit, tag v<version> and push. The Packages
# workflow then builds the .deb/.rpm files and publishes the GitHub release.
#
#   tools/release.sh <version>        e.g. tools/release.sh 1.6.1
#
# CHANGES.md must already have a "# Version <version> - unreleased" section
# at the top; its bullets become the Debian and RPM changelog entries.
# Safe to re-run: steps that are already done are skipped.
set -euo pipefail

version=${1:?usage: tools/release.sh <version>}
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must look like 1.2.3"; exit 1; }
cd "$(git rev-parse --show-toplevel)"

default=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || echo main)
branch=$(git branch --show-current)
[ "$branch" = "$default" ] || { echo "release from $default, not $branch"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "working tree is not clean"; exit 1; }
git fetch -q origin
[ "$(git rev-parse HEAD)" = "$(git rev-parse "origin/$default")" ] || { echo "$default is not in sync with origin/$default"; exit 1; }
git rev-parse -q --verify "refs/tags/v$version" >/dev/null && { echo "tag v$version already exists"; exit 1; }

date=$(date +%Y-%m-%d)
name=$(git config user.name); email=$(git config user.email)

# CHANGES.md: stamp the date on this version's section and collect its bullets.
head -1 CHANGES.md | grep -q -E "^# Version $version - (unreleased|[0-9-]+)$" \
  || { echo "CHANGES.md must start with '# Version $version - unreleased'"; exit 1; }
sed -i "1s/.*/# Version $version - $date/" CHANGES.md
bullets=$(awk 'NR>1 && /^# Version/{exit} NR>1' CHANGES.md | sed '/^\s*$/d')

# meson.build
sed -i "s/^\(  version: '\)[0-9.]*\(',\)/\1$version\2/" meson.build

# debian/changelog: prepend an entry unless the top one is already this version.
if ! head -1 debian/changelog | grep -q "^peek ($version-1)"; then
  {
    echo "peek ($version-1) unstable; urgency=medium"
    echo
    echo "  * New upstream release $version."
    echo "$bullets" | sed 's/^- /  * /; s/^  \([^*]\)/    \1/'
    echo
    echo " -- $name <$email>  $(date -R)"
    echo
    cat debian/changelog
  } >debian/changelog.new && mv debian/changelog.new debian/changelog
fi

# rpm/peek.spec: version and a %changelog entry.
sed -i "s/^\(Version:\s*\)[0-9.]*/\1$version/" rpm/peek.spec
if ! grep -q -- "- $version-1\$" rpm/peek.spec; then
  entry="* $(LC_ALL=C date '+%a %b %d %Y') $name <$email> - $version-1
$(echo "$bullets" | sed 's/^- /- /; s/^  \([^-]\)/  \1/')
"
  awk -v entry="$entry" '{print} /^%changelog$/{print entry}' rpm/peek.spec >rpm/peek.spec.new && mv rpm/peek.spec.new rpm/peek.spec
fi

# AppStream release list.
appdata=data/com.uploadedlobster.peek.appdata.xml.in
grep -q "<release version=\"$version\"" "$appdata" \
  || sed -i "s#^  <releases>#  <releases>\n    <release version=\"$version\" date=\"$date\" />#" "$appdata"

echo; git --no-pager diff --stat; echo; git --no-pager diff
echo
read -r -p "Commit, tag v$version and push to origin/$default? [y/N] " answer
[ "$answer" = y ] || [ "$answer" = Y ] || { echo "aborted; changes left in the working tree"; exit 1; }

git commit -q -am "chore: release $version"
git tag -a "v$version" -m "Peek $version"
git push origin "$default" "v$version"
echo "pushed. Packages workflow: gh run watch   release: gh release view v$version"
