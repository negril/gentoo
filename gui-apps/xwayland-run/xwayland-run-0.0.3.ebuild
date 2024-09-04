# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..13} )

inherit meson python-single-r1

DESCRIPTION="Run a command in a virtual wayland server environment"
HOMEPAGE="https://gitlab.freedesktop.org/ofourdan/xwayland-run"

if [[ ${PV} = *9999* ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://gitlab.freedesktop.org/ofourdan/${PN}.git"
else
	SRC_URI="
		https://gitlab.freedesktop.org/ofourdan/${PN}/-/archive/${PV}/${P}.tar.bz2
	"
	KEYWORDS="~amd64 ~arm64"
fi

LICENSE="GPL-2+"
SLOT="0"

COMPOSITORS=(
	# gnome-kiosk
	kwin
	cage
	mutter
	+weston
)

IUSE="${COMPOSITORS[*]}"

REQUIRED_USE="${PYTHON_REQUIRED_USE}
	|| ( ${COMPOSITORS[*]##+} )
"
RDEPEND="${PYTHON_DEPS}
	x11-apps/xauth
	cage? ( gui-wm/cage )
	kwin? ( kde-plasma/kwin )
	mutter? ( x11-wm/mutter[wayland] )
	weston? ( dev-libs/weston[wayland-compositor,xwayland] )
"

src_configure() {
	local ENABLED_COMPOSITORS=()
	for COMPOSITOR in "${COMPOSITORS[@]##+}"; do
		use "${COMPOSITOR}" && ENABLED_COMPOSITORS+=( "${COMPOSITOR}" )
	done

	local emesonargs=(
		-Dcompositor="$( IFS=','; echo "${ENABLED_COMPOSITORS[*]}")"
	)

	meson_src_configure
}

src_install() {
	meson_src_install

	python_optimize
}
