# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake flag-o-matic

DESCRIPTION="GUI binding for using Coin/Open Inventor with Qt"
HOMEPAGE="https://github.com/coin3d/soqt https://github.com/coin3d/coin/wiki"

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/coin3d/${PN,,}.git"
else
	SRC_URI="https://github.com/coin3d/${PN,,}/releases/download/v${PV}/${P/${PN}/${PN,,}}-src.tar.gz"
	S="${WORKDIR}/${PN,,}"

	KEYWORDS="~amd64 ~x86"
fi

LICENSE="GPL-2"
SLOT="0"
IUSE="debug doc test"

RESTRICT="test"

RDEPEND="
	dev-qt/qtbase:6[gui,opengl,widgets]
	media-libs/coin
	virtual/opengl[X]
	x11-libs/libX11
	x11-libs/libXi
"
DEPEND="${RDEPEND}"
BDEPEND="
	virtual/pkgconfig
	x11-base/xorg-proto
	doc? ( app-text/doxygen )
"

DOCS=(
	AUTHORS
	ChangeLog
	HACKING
	NEWS
	README
)

src_configure() {
	use debug && append-cppflags "-D${PN^^}_DEBUG=1"

	local mycmakeargs=(
		-D${PN^^}_BUILD_SHARED_LIBS="yes"

		-D${PN^^}_BUILD_AWESOME_DOCUMENTATION="$(usex doc)"
		-D${PN^^}_BUILD_DOCUMENTATION="$(usex doc)"
		-D${PN^^}_BUILD_DOC_MAN="$(usex doc)"
		-D${PN^^}_BUILD_INTERNAL_DOCUMENTATION="no"

		# Interactive test programs
		-D${PN^^}_BUILD_TESTS="$(usex test)"
		-D${PN^^}_USE_QT5="no"
		-D${PN^^}_USE_QT6="yes"
		-D${PN^^}_VERBOSE="$(usex debug)"
	)

	cmake_src_configure
}
