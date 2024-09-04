# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..13} )
PYTHON_REQ_USE='xml(+)'
inherit meson-multilib python-any-r1 virtualx xdg

if [[ ${PV} = 9999* ]]; then
	EGIT_REPO_URI="https://github.com/anholt/${PN}.git"
	inherit git-r3
else
	SRC_URI="https://github.com/anholt/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~alpha amd64 arm arm64 ~hppa ~ia64 ~loong ~mips ppc ppc64 ~riscv ~s390 sparc x86"
fi

DESCRIPTION="Library for handling OpenGL function pointer management"
HOMEPAGE="https://github.com/anholt/libepoxy"

LICENSE="MIT"
SLOT="0"
IUSE="test +X"

RESTRICT="!test? ( test )"

RDEPEND="
	media-libs/libglvnd[X?,${MULTILIB_USEDEP}]
"
DEPEND="${RDEPEND}
	X? (
		x11-base/xorg-proto
		x11-libs/libX11[${MULTILIB_USEDEP}]
	)
"
BDEPEND="${PYTHON_DEPS}
	virtual/pkgconfig
"

PATCHES=( "${FILESDIR}"/libepoxy-1.5.10-libopengl-fallback.patch )

multilib_src_configure() {
	local emesonargs=(
		-Degl=yes
		-Dglx=$(usex X)
		$(meson_use X x11)
		$(meson_use test tests)
	)
	meson_src_configure
}

multilib_src_test() {
	if [[ ! -d /sys/module/nvidia ]]; then
		einfo "loading nvidia module"
		nvidia-modprobe || die
	fi

	if [[ ! -d /sys/module/nvidia_uvm ]]; then
		einfo "loading nvidia_uvm module"
		nvidia-modprobe -u || die
	fi

	local i WRITE

	# /dev/dri/card*
	# /dev/dri/renderD*
	readarray -t dri <<<"$(find /sys/module/nvidia/drivers/*/*:*:*.*/drm -mindepth 1 -maxdepth 1 -type d -exec basename {} \;| sed 's:^:/dev/dri/:')"

	# /dev/nvidia{0-9}
	readarray -t cards <<<"$(find /dev -regextype sed -regex '/dev/nvidia[0-9]*')"

	WRITE+=(
		"${dri[@]}"
		"${cards[@]}"
		/dev/nvidiactl
		/dev/nvidia-uvm*

		# for portage
		/proc/self/task/
	)
	for i in "${WRITE[@]}"; do
		einfo "addwrite $i"
		addwrite "$i"
	done

	local -x LIBGL_ALWAYS_SOFTWARE=true
	xdg_environment_reset
	virtx meson_src_test
}
