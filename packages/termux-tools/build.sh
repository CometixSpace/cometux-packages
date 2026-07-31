TERMUX_PKG_HOMEPAGE=https://termux.dev/
TERMUX_PKG_DESCRIPTION="Basic system tools for Termux"
TERMUX_PKG_LICENSE="GPL-3.0"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="1.46.0+really1.45.0"
TERMUX_PKG_REVISION=1
TERMUX_PKG_SRCURL=https://github.com/termux/termux-tools/archive/refs/tags/v1.45.0.tar.gz
TERMUX_PKG_SHA256=1ae29b1b875d95cc626dae323b45a2ace759969862d96094b2fa6d13bffe20d2
TERMUX_PKG_ESSENTIAL=true
#TERMUX_PKG_AUTO_UPDATE=true
TERMUX_PKG_UPDATE_TAG_TYPE="newest-tag"
TERMUX_PKG_BREAKS="termux-keyring (<< 1.9)"
TERMUX_PKG_CONFLICTS="procps (<< 3.3.15-2)"
TERMUX_PKG_SUGGESTS="termux-api"

# Some of these packages are not dependencies and used only to ensure
# that core packages are installed after upgrading (we removed busybox
# from essentials).
TERMUX_PKG_DEPENDS="bzip2, coreutils, curl, dash, diffutils, findutils, gawk, grep, gzip, less, procps, psmisc, sed, tar, termux-am (>= 0.8.0), termux-am-socket (>= 1.5.0), termux-core, termux-exec, util-linux, xz-utils, dialog"

# Optional packages that are distributed as part of bootstrap archives.
TERMUX_PKG_RECOMMENDS="ed, dos2unix, inetutils, net-tools, patch, unzip"

termux_step_pre_configure() {
	autoreconf -vfi
}

termux_step_post_make_install() {
	TERMUX_PKG_CONFFILES="$(cat "$TERMUX_PKG_BUILDDIR/conffiles")"

	# Replace the upstream mirror set with our repository.
	#
	# pkg does not read sources.list to decide where to fetch from: it
	# weighs the files under etc/termux/mirrors, picks one, and rewrites
	# sources.list from it. Shipping the stock list therefore routes
	# installs to official Termux mirrors, whose debs carry the
	# com.termux prefix and cannot be unpacked here — dpkg fails on
	# 'unable to stat ./data/data/com.termux'. It also makes apt believe
	# dozens of packages are upgradable against a tree we do not use.
	rm -rf "$TERMUX_PREFIX/etc/termux/mirrors"
	mkdir -p "$TERMUX_PREFIX/etc/termux/mirrors"
	cat <<- EOF > "$TERMUX_PREFIX/etc/termux/mirrors/default"
	# This file is sourced by pkg
	# The Cometux repository: packages rebuilt for the
	# ${TERMUX_APP_PACKAGE} prefix. Stock Termux mirrors are
	# ABI-incompatible with a renamed app, so this is the only entry.
	WEIGHT=1
	MAIN="https://cometixspace.github.io/cometux-packages/termux-main"
	ROOT="https://cometixspace.github.io/cometux-packages/termux-root"
	EOF

	# Cometux branding (ZeroTermux-style fork policy: user-visible
	# strings only, the termux-* command namespace stays untouched).
	local motd
	for motd in "$TERMUX_PREFIX/etc/motd" "$TERMUX_PREFIX/etc/motd.sh"; do
		[ -f "$motd" ] || continue
		# In-place word swaps only: the wide variant interleaves these
		# lines with the block-art logo, so no line may be dropped.
		sed -i \
			-e 's|Welcome to Termux!|Welcome to Cometux!|g' \
			-e 's|Donate:|Builds:|g' \
			-e 's|https://termux.dev/docs|https://github.com/CometixSpace/cometux-packages|g' \
			-e 's|https://termux.dev/donate|https://github.com/CometixSpace/cometux-packages/releases|g' \
			-e 's|https://termux.dev/community|https://github.com/CometixSpace|g' \
			-e 's|Termux version:|Cometux base:|g' \
			"$motd"
	done
}

termux_step_create_debscripts() {
	# The preinst template in the termux-tools source hard-codes the stock
	# prefix — the same literal-path issue the massage step fixes for
	# packaged files, but maintainer scripts never pass through massage.
	cat <<- EOF > ./preinst
	$(sed "s|/data/data/com\.termux|/data/data/${TERMUX_APP_PACKAGE}|g" "$TERMUX_PKG_BUILDDIR/preinst")
	EOF
}
