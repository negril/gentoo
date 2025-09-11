# Copyright 2019-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..13} )
inherit python-any-r1 edo flag-o-matic toolchain-funcs

DESCRIPTION="BLAS-like Library Instantiation Software Framework"
HOMEPAGE="https://github.com/flame/blis"
SRC_URI="https://github.com/flame/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~ppc64 ~x86"
CPU_USE=(
	cpu_flags_ppc_{vsx,vsx3}
	cpu_flags_arm_{neon,v7,v8,sve}
	cpu_flags_x86_{ssse3,avx,fma3,fma4,avx2,avx512vl}
)
IUSE="doc eselect-ldso openmp pthread serial static-libs 64bit-index ${CPU_USE[@]}"
REQUIRED_USE="
	?? ( openmp pthread serial )
	?? ( eselect-ldso 64bit-index )"

DEPEND="
	eselect-ldso? (
		!app-eselect/eselect-cblas
		>=app-eselect/eselect-blas-0.2
	)"

RDEPEND="${DEPEND}"
BDEPEND="
	${PYTHON_DEPS}
	dev-lang/perl
"

PATCHES=(
	"${FILESDIR}"/${PN}-0.6.0-blas-provider.patch
	# to prevent QA Notice: pkg-config files with wrong LDFLAGS detected
	"${FILESDIR}"/${PN}-0.8.1-pkg-config.patch
	"${FILESDIR}"/${PN}-0.9.0-rpath.patch
	"${FILESDIR}"/${PN}-1.0-no-helper-headers.patch
)

get_confname() {
	local confname="generic"
	if use x86 || use amd64; then
		if use cpu_flags_x86_avx512vl; then
			confname="skx"
		elif use cpu_flags_x86_avx2; then
			confname="haswell"
		elif use cpu_flags_x86_avx && use cpu_flags_x86_fma4 && use cpu_flags_x86_fma3; then
			confname="piledriver"
		elif use cpu_flags_x86_avx && use cpu_flags_x86_fma4; then
			confname="bulldozer"
		elif use cpu_flags_x86_avx && use cpu_flags_x86_fma3; then
			confname="sandybridge"
		elif use cpu_flags_x86_ssse3; then
			confname="penryn"
		fi
	elif use arm || use arm64; then
		if use cpu_flags_arm_sve; then
			confname="armsve"
		elif use cpu_flags_arm_v8; then
			confname="cortexa53"
		elif use cpu_flags_arm_neon && use cpu_flags_arm_v7; then
			confname="cortexa9"
		elif use arm64; then
			confname="arm64"
		elif use arm; then
			confname="arm32"
		fi
	elif use ppc || use ppc64; then
		confname="power"
		if use cpu_flags_ppc_vsx3; then
			confname="power9"
		elif use cpu_flags_ppc_vsx; then
			confname="power7"
		fi
	fi
	echo "${confname}"
}

src_configure() {
	# https://github.com/flame/blis/pull/874
	if use cpu_flags_x86_avx2 && tc-is-gcc && [[ $(gcc-major-version) -ge 15 ]]; then
		append-cflags "-fno-tree-vectorize"
	fi

	local BLIS_FLAGS=()

	# determine flags
	if use openmp; then
		BLIS_FLAGS+=( -t openmp )
	elif use pthread; then
		BLIS_FLAGS+=( -t pthreads )
	elif use serial; then
		BLIS_FLAGS+=( -t no )
	else
		eqawarn "no threading model selected, defaulting to serial"
		BLIS_FLAGS+=( -t no )
	fi

	if use 64bit-index; then
		BLIS_FLAGS+=(
			-b 64
			-i 64
		)
	fi

	local myeconfargs=(
		--enable-verbose-make
		--prefix="${BROOT}/usr"
		--libdir="${BROOT}/usr/$(get_libdir)"
		"$(use_enable static-libs static)"
		--enable-blas
		--enable-cblas
		"${BLIS_FLAGS[@]}"
		--enable-shared
		"$(get_confname)"
	)

	# This is not an autotools configure file. We don't use econf here.
	CC="$(tc-getCC)" AR="$(tc-getAR)" RANLIB="$(tc-getRANLIB)" edo ./configure "${myeconfargs[@]}"
}

src_compile() {
	DEB_LIBBLAS=libblas.so.3 \
	DEB_LIBCBLAS=libcblas.so.3 \
	LDS_BLAS="${FILESDIR}/blas.lds" \
	LDS_CBLAS="${FILESDIR}/cblas.lds" \
		default
}

src_test() {
	LD_LIBRARY_PATH=lib/$(get_confname) emake testblis-fast
	edo ./testsuite/check-blistest.sh ./output.testsuite
}

src_install() {
	default

	if use doc; then
		dodoc README.md docs/*.md
	fi

	if use eselect-ldso; then
		insinto /usr/$(get_libdir)/blas/blis
		doins lib/*/lib{c,}blas.so.3
		dosym libblas.so.3 usr/$(get_libdir)/blas/blis/libblas.so
		dosym libcblas.so.3 usr/$(get_libdir)/blas/blis/libcblas.so
	fi
}

pkg_postinst() {
	if ! use eselect-ldso; then
		return
	fi

	local libdir=$(get_libdir) me="blis"

	# check blas
	eselect blas add "${libdir}" "${EROOT}/usr/${libdir}/blas/${me}" "${me}"
	local current_blas=$(eselect blas show "${libdir}" | cut -d' ' -f2)
	if [[ ${current_blas} == "${me}" || -z ${current_blas} ]]; then
		eselect blas set "${libdir}" "${me}"
		elog "Current eselect: BLAS/CBLAS ($libdir) -> [${current_blas}]."
	else
		elog "Current eselect: BLAS/CBLAS ($libdir) -> [${current_blas}]."
		elog "To use blas [${me}] implementation, you have to issue (as root):"
		elog "\t eselect blas set ${libdir} ${me}"
	fi
}

pkg_postrm() {
	if use eselect-ldso; then
		eselect blas validate
	fi
}
