# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake flag-o-matic

DESCRIPTION="COLLADA Document Object Model (DOM) C++ Library"
HOMEPAGE="https://github.com/Gepetto/collada-dom"

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/Gepetto/collada-dom.git"
else
	SRC_URI="
		https://github.com/Gepetto/collada-dom/archive/v${PV}.tar.gz -> ${P}.tar.gz
	"
	KEYWORDS="~amd64 ~arm ~arm64 ~hppa ~ppc ~ppc64 ~x86"
fi

LICENSE="MIT"
SLOT="0/$(ver_rs 1-2 '' "$(ver_cut 1-2)")"

RDEPEND="
	dev-libs/boost:=
	dev-libs/libxml2:=
	dev-libs/libpcre[cxx]
	virtual/minizip:=
"
DEPEND="${RDEPEND}"
BDEPEND="
	virtual/pkgconfig
"

PATCHES=(
	"${FILESDIR}/${PN}-2.5.0-boost-1.89.patch" # bugs 968458
	"${FILESDIR}/${PN}-2.5.0-zlib-1.3.2.patch"
)

src_configure() {
	# bug 618960
	append-cxxflags -std=c++14

	cmake_src_configure
}
