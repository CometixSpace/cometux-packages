#!/usr/bin/env bash
# Publish the Cometux apt repository to GitHub Pages (group B).
#
# Usage: publish-apt-repo.sh <debs-dir> [checkout-dir]
#
# Takes a directory of built .deb files (the `debs` artifact of the
# bootstrap workflow, or a packages.yml run), regenerates the repository
# tree with termux-apt-repo (signed with the "Cometux Repository
# Signing" GPG key, whose public half ships in termux-keyring), and
# force-pushes it to the gh-pages branch serving
#   https://cometixspace.github.io/cometux-packages/termux-main
#
# Packages whose recipes have pending unreleased changes must be dropped
# from the input first if their version was not bumped.

set -euo pipefail

DEBS_DIR="${1:?usage: publish-apt-repo.sh <debs-dir> [checkout-dir]}"
CHECKOUT_DIR="${2:-/tmp/cometux-apt-pages}"
REPO_SLUG="CometixSpace/cometux-packages"
SIGNER="Cometux Repository Signing"

command -v termux-apt-repo >/dev/null || {
	echo "termux-apt-repo not found (pip install termux-apt-repo)" >&2
	exit 1
}
gpg --list-secret-keys "$SIGNER" >/dev/null || {
	echo "signing key '$SIGNER' not in the local GPG keyring" >&2
	exit 1
}

rm -rf "$CHECKOUT_DIR"
git clone --depth 1 --branch gh-pages "https://github.com/$REPO_SLUG" \
	"$CHECKOUT_DIR" 2>/dev/null || {
	mkdir -p "$CHECKOUT_DIR"
	git -C "$CHECKOUT_DIR" init -b gh-pages
	git -C "$CHECKOUT_DIR" remote add origin "https://github.com/$REPO_SLUG"
}

rm -rf "$CHECKOUT_DIR/termux-main"
termux-apt-repo -s "$DEBS_DIR" "$CHECKOUT_DIR/termux-main" stable main

# Pages must not run the tree through Jekyll.
touch "$CHECKOUT_DIR/.nojekyll"

git -C "$CHECKOUT_DIR" add -A
git -C "$CHECKOUT_DIR" commit -m "apt repo refresh $(date -u +%Y-%m-%dT%H:%MZ)"
git -C "$CHECKOUT_DIR" push -f origin gh-pages

echo "Published. Enable Pages (branch gh-pages, root) once via:"
echo "  gh api -X POST repos/$REPO_SLUG/pages -f 'source[branch]=gh-pages' -f 'source[path]=/'"
