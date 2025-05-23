# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

VERIFY_SIG_OPENPGP_KEY_PATH=/usr/share/openpgp-keys/andresimon.asc

inherit toolchain-funcs java-pkg-opt-2 verify-sig

DESCRIPTION="Artistic Style is a re-indenter and reformatter for C, C++ and Java source code"
HOMEPAGE="https://astyle.sourceforge.net/ https://gitlab.com/saalen/astyle"
SRC_URI="
	https://downloads.sourceforge.net/astyle/${P}.tar.bz2
	http://www.andre-simon.de/zip/${P}.tar.bz2
	verify-sig? ( http://www.andre-simon.de/zip/${P}.tar.bz2.asc )
"

LICENSE="MIT"
SLOT="0/3.2"
KEYWORDS="amd64 arm64 ppc ppc64 ~riscv x86 ~amd64-linux ~x86-linux ~ppc-macos"
IUSE="java static-libs"

DOCS=( README.md  examples/ )
HTML_DOCS=( doc/. )

DEPEND="java? ( >=virtual/jdk-1.8:* )"
RDEPEND="java? ( >=virtual/jre-1.8:* )"
BDEPEND="verify-sig? ( sec-keys/openpgp-keys-andresimon )"

src_prepare() {
	if use java; then
		java-pkg-opt-2_src_prepare
		sed	-e "s:^\(JAVAINCS\s*\)=.*$:\1= $(java-pkg_get-jni-cflags):" \
			-e "s:ar crs:$(tc-getAR) crs:" \
			-i build/gcc/Makefile || die
	else
		default
	fi

	# rename examples directory for simpler installation
	mv file/ examples/ || die
}

src_configure() {
	tc-export CXX
	default
}

src_compile() {
	# ../build/clang/Makefile is identical except for CXX line.
	emake CXX="$(tc-getCXX)" -f ../build/gcc/Makefile -C src \
		${PN} \
		shared \
		$(usev java) \
		$(usev static-libs static)
}

src_install() {
	doheader src/${PN}.h

	pushd src/bin >/dev/null || die
	dobin ${PN}

	local libastylename="lib${PN}.so.${SLOT##*/}.0"
	local libastylejname="lib${PN}j.so.${SLOT##*/}.0"
	local libdestdir="/usr/$(get_libdir)"

	dolib.so "${libastylename}"
	dosym "${libastylename}" "${libdestdir}/lib${PN}.so.$(ver_cut 1 ${SLOT##*/})"
	dosym "${libastylename}" "${libdestdir}/lib${PN}.so"

	if use java; then
		dolib.so "${libastylejname}"
		dosym "${libastylejname}" "${libdestdir}/lib${PN}j.so.$(ver_cut 1 ${SLOT##*/})"
		dosym "${libastylejname}" "${libdestdir}/lib${PN}j.so"
	fi

	use static-libs && dolib.a lib${PN}.a

	popd >/dev/null || die

	einstalldocs
}
