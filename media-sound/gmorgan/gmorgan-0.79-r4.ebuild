# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools

DESCRIPTION="Opensource software rhythm station"
HOMEPAGE="https://gmorgan.sourceforge.net/"
SRC_URI="https://downloads.sourceforge.net/gmorgan/${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="amd64 x86"
IUSE="nls"

RDEPEND="
	media-libs/alsa-lib
	x11-libs/fltk:1="
DEPEND="${RDEPEND}"
BDEPEND="nls? ( sys-devel/gettext )"

PATCHES=(
	"${FILESDIR}"/${P}-remove-gettext-version-check.patch
	"${FILESDIR}"/${P}-manpages.patch
	"${FILESDIR}"/${P}-remove-dirs.patch
	"${FILESDIR}"/${P}-remove-old-docs.patch
	"${FILESDIR}"/${P}-gcc6.patch
	"${FILESDIR}"/${P}-clang.patch
	"${FILESDIR}"/${P}-clang16.patch
)

src_prepare() {
	default
	sed -i -e "s#/usr/local/share/#/usr/share/#" src/gmorgan.chord.cpp || die
	eautoreconf
}

src_configure() {
	econf $(use_enable nls)
}

src_install() {
	default
	doman man/gmorgan.1
}
