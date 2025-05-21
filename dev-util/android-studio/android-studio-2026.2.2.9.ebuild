# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop wrapper

# fixing "installs files with unresolved SONAME dependencies" needs new QA var
# QA_FLAGS_IGNORED="
QA_PREBUILT="
	opt/${PN}/bin/*
	opt/${PN}/jbr/bin/*
	opt/${PN}/jbr/lib/*
	opt/${PN}/jbr/lib/jli/*
	opt/${PN}/jbr/lib/server/*
	opt/${PN}/lib/pty4j-native/linux/*/*
	opt/${PN}/plugins/android/resources/installer/*/*
	opt/${PN}/plugins/android/resources/native/*
	opt/${PN}/plugins/android/resources/perfetto/*/*
	opt/${PN}/plugins/android/resources/screen-sharing-agent/*/*
	opt/${PN}/plugins/android/resources/simpleperf/*/*
	opt/${PN}/plugins/android/resources/trace_processor_daemon/*
	opt/${PN}/plugins/android/resources/transport/*/*
	opt/${PN}/plugins/android/resources/transport/native/agent/*/*
	opt/${PN}/plugins/android-ndk/resources/lldb/android/*/*
	opt/${PN}/plugins/android-ndk/resources/lldb/bin/*
	opt/${PN}/plugins/android-ndk/resources/lldb/lib/python3.9/lib-dynload/*
	opt/${PN}/plugins/android-ndk/resources/lldb/lib64/*
	opt/${PN}/plugins/design-tools/resources/layoutlib/data/linux/lib64/*
	opt/${PN}/plugins/c-clangd/bin/clang/linux/*/*
	opt/${PN}/plugins/webp/lib/libwebp/linux/*
"

DESCRIPTION="Android development environment based on IntelliJ IDEA"
HOMEPAGE="https://developer.android.com/studio"
SRC_URI="https://edgedl.me.gvt1.com/android/studio/ide-zips/${PV}/${PN}-rabbit2-patch1-linux.tar.gz"
S=${WORKDIR}/${PN}
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
	>=app-arch/bzip2-1.0.8-r4
	dev-libs/wayland
	media-libs/alsa-lib
	>=media-libs/freetype-2.12.1-r1
	|| (
		gnome-extra/zenity
		kde-apps/kdialog
		x11-apps/xmessage
		x11-libs/libnotify
	)
	sys-libs/ncurses-compat:5[tinfo]
	virtual/libcrypt
	>=virtual/zlib-1.2.13-r1
	>=x11-libs/libX11-1.8.1
	>=x11-libs/libXext-1.3.5
	x11-libs/libXi
	>=x11-libs/libXrender-0.9.11
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
	:;
}

src_compile() {
	:;
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
