# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# fixing "installs files with unresolved SONAME dependencies" needs new QA var
QA_FLAGS_IGNORED="
	opt/${PN}/*
"

inherit desktop wrapper

DESCRIPTION="Android development environment based on IntelliJ IDEA"
HOMEPAGE="https://developer.android.com/studio"

SRC_URI="https://redirector.gvt1.com/edgedl/android/studio/ide-zips/${PV}/${P}-linux.tar.gz"
S="${WORKDIR}/${PN}"

LICENSE="Apache-2.0 android BSD BSD-2 CDDL-1.1 CPL-0.5
	EPL-1.0 GPL-2 GPL-2+ JDOM IJG LGPL-2.1 MIT
	MPL-1.1 MPL-2.0 NPL-1.1 OFL-1.1 ZLIB"

SLOT="0"
KEYWORDS="~amd64"

IUSE="selinux"

RESTRICT="bindist mirror strip"

RDEPEND="
	selinux? (
		sec-policy/selinux-android
	)
	app-arch/bzip2
	dev-libs/wayland
	media-libs/alsa-lib
	media-libs/freetype
	|| (
		gnome-extra/zenity
		kde-apps/kdialog
		x11-apps/xmessage
		x11-libs/libnotify
	)
	sys-libs/ncurses-compat:5[tinfo]
	sys-libs/zlib
	virtual/libcrypt
	x11-libs/libX11
	x11-libs/libXext
	x11-libs/libXi
	x11-libs/libXrender
	x11-libs/libXtst
"

src_prepare() {
	default

	cat <<-EOF >> bin/idea.properties || die
		#-----------------------------------------------------------------------
		# Disable automatic updates as these are handled through Gentoo's
		# package manager.
		#-----------------------------------------------------------------------
		ide.no.platform.update=Gentoo
	EOF
}

src_configure() {
	:
}

src_compile() {
	:
}

src_install() {
	local dir="/opt/${PN}"

	newicon "bin/studio.png" "${PN}.png"
	make_wrapper "${PN}" "${EPREFIX}${dir}/bin/studio"
	make_desktop_entry \
		"${EPREFIX}${dir}/bin/studio" \
		"Android Studio" \
		"${PN}" \
		"Development;IDE" \
		"StartupWMClass=jetbrains-studio"

	# recommended by: https://confluence.jetbrains.com/display/IDEADEV/Inotify+Watches+Limit
	dodir /usr/lib/sysctl.d
	echo "fs.inotify.max_user_watches = 524288" > "${ED}/usr/lib/sysctl.d/30-${PN}-inotify-watches.conf" || die

	mkdir -p "${ED}/${dir}" || die
	mv ./* "${ED}/${dir}" || die
}

pkg_postrm() {
	elog "Android Studio data files were not removed."
	elog "If there will be no other programs using them anymore"
	elog "(especially another flavor of Android Studio)"
	elog "remove manually following folders:"
	elog ""
	elog "		~/.android/"
	elog "		~/.config/Google/AndroidStudio*/"
	elog "		~/.local/share/Google/AndroidStudio*/"
	elog "		~/Android/"
	elog ""
	elog "Also, if there are no other programs using Gradle, remove:"
	elog ""
	elog "		~/.gradle/"
}
