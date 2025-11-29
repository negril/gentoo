# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

MY_PN="OpenJPH"

inherit cmake-multilib flag-o-matic

DESCRIPTION="Open source implementation of JPH (high-throughput JPEG2000) library"
HOMEPAGE="https://github.com/aous72/OpenJPH"

if [[ ${PV} = *9999* ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/aous72/${PN}.git"
	TEST_REPO_URI="https://github.com/aous72/jp2k_test_codestreams.git"
else
	TEST_COMMIT="eda0844b9f3be47d9b64194bcea5eb1ac2285e39"
	SRC_URI="
		https://github.com/aous72/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz
		test? (
			https://github.com/aous72/jp2k_test_codestreams/archive/${TEST_COMMIT}.tar.gz -> ${PN}-jp2k_test_codestreams-${TEST_COMMIT:0:8}.tar.gz
		)
	"
	S="${WORKDIR}/${MY_PN}-${PV}"
	KEYWORDS="~amd64"
fi

LICENSE="BSD-2"
SLOT="0" # based on SONAME
IUSE="doc test tiff +tools"

declare -A CPU_FEATURES=(
	[SSE2]="x86"
	[AVX]="x86"
	[AVX2]="x86"
	[AVX512F]="x86"
	[NEON]="arm"
	[SSE]="x86"
	[SSE2]="x86"
	[SSE4_1]="x86"
	[SSSE3]="x86"
)

add_cpu_features_use() {
	for flag in "${!CPU_FEATURES[@]}"; do
		IFS=$';' read -r arch use <<< "${CPU_FEATURES[${flag}]}"
		IUSE+=" cpu_flags_${arch}_${use:-${flag,,}}"
	done
}
add_cpu_features_use

RESTRICT="!test? ( test )"
REQUIRED_USE="test? ( tools )"
RDEPEND="
	tiff? ( media-libs/tiff:=[${MULTILIB_USEDEP}] )
"
DEPEND="${RDEPEND}"
BDEPEND="
	virtual/pkgconfig
	doc? ( app-text/doxygen )
	test? ( dev-cpp/gtest[${MULTILIB_USEDEP}] )
"

DOCS=( README.md )

PATCHES=(
	"${FILESDIR}/${PN}-0.25.0-use_prefetched_test_data_and_gtest.patch"
	# "${FILESDIR}/${PN}-0.25.3-fix-array-initialization.patch"
	"${FILESDIR}/${PN}-0.25.3-fix-ub.patch"
)

src_unpack() {
	if [[ "${PV}" == "9999" ]]; then
		git-r3_fetch
		git-r3_checkout

		if use test; then
			git-r3_fetch "${TEST_REPO_URI}"
			git-r3_checkout "${TEST_REPO_URI}" "${S}/tests/jp2k_test_codestreams"
		fi
	else
		default

		if use test; then
			mv "${WORKDIR}/jp2k_test_codestreams-${TEST_COMMIT}" "${S}/tests/jp2k_test_codestreams" || \
				die "Failed to rename test data"
		fi
	fi
}

multilib_src_configure() {
	# append-flags -fno-strict-aliasing

	local mycmakeargs=(
		-DCMAKE_C_STANDARD=23
		-DCMAKE_CXX_STANDARD=20

		-DOJPH_BUILD_EXECUTABLES="$(usex tools)"
		-DOJPH_BUILD_STREAM_EXPAND="$(usex tools)"
		-DOJPH_ENABLE_TIFF_SUPPORT="$(usex tiff)"

		-DOJPH_DISABLE_AVX2="$(usex !cpu_flags_x86_avx2)"
		-DOJPH_DISABLE_AVX512="$(usex !cpu_flags_x86_avx512f)"
		-DOJPH_DISABLE_AVX="$(usex !cpu_flags_x86_avx)"
		-DOJPH_DISABLE_NEON="$(usex !cpu_flags_arm_neon)"
		-DOJPH_DISABLE_SIMD="no"
		-DOJPH_DISABLE_SSE2="$(usex !cpu_flags_x86_sse2)"
		-DOJPH_DISABLE_SSE4="$(usex !cpu_flags_x86_sse4_1)"
		-DOJPH_DISABLE_SSE="$(usex !cpu_flags_x86_sse)"
		-DOJPH_DISABLE_SSSE3="$(usex !cpu_flags_x86_ssse3)"

		-DOJPH_BUILD_TESTS="$(usex test)"
	)

	cmake_src_configure
}

multilib_src_test() {
	ln -svf "${S}/tests/jp2k_test_codestreams" "${BUILD_DIR}/tests/jp2k_test_codestreams" || die

	cmake_src_test --output-on-failure --extra-verbose
}

multilib_src_install() {
	cmake_src_install
}

multilib_src_install_all() {
	if use doc; then
		doxygen "${S}/docs" || die
		dodoc -r html
	fi
}
