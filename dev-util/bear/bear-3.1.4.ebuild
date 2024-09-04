# Copyright 2020-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..11} )

inherit cmake python-any-r1

DESCRIPTION="Build EAR generates a compilation database for clang tooling"
HOMEPAGE="https://github.com/rizsotto/Bear"
SRC_URI="https://github.com/rizsotto/Bear/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~loong ~ppc64 ~riscv ~x86"
IUSE="test"

RDEPEND="
	>=dev-db/sqlite-3.14:=
	>=dev-libs/libfmt-9.1.0:=
	dev-libs/protobuf:=
	>=dev-libs/spdlog-1.11.0:=
	>=net-libs/grpc-1.49.2:=
"

DEPEND="
	${RDEPEND}
	>=dev-cpp/nlohmann_json-3.11.2:=
	test? (
		>=dev-cpp/gtest-1.10
	)
"

BDEPEND="
	virtual/pkgconfig
	test? (
		dev-build/libtool
		$(python_gen_any_dep '
			dev-python/lit[${PYTHON_USEDEP}]
		')
	)
"

RESTRICT="!test? ( test )"

S="${WORKDIR}/${P^}"

PATCHES=(
	"${FILESDIR}"/${PN}-3.0.21-clang16-tests.patch
	"${FILESDIR}"/${PN}-3.0.21-libfmt-10.0.0.patch
	"${FILESDIR}/${PN}-3.1.4-tests.patch"
)

pkg_setup() {
	use test && python-any-r1_pkg_setup
}

src_prepare() {
	cmake_src_prepare
	# Turn off testing before installation
	sed -i 's/TEST_BEFORE_INSTALL/TEST_EXCLUDE_FROM_MAIN/g' CMakeLists.txt || die

	# https://github.com/rizsotto/Bear/issues/445
	# cannot find 'ld'
	rm test/cases/compilation/output/assembly_sources.mk
	rm test/cases/compilation/output/bug439.mk

	# recognition failed: No tools recognize this execution.
	rm test/cases/compilation/output/define_with_escaped_quote.sh
	rm test/cases/compilation/output/define_with_quote.sh
	rm test/cases/compilation/output/flags_filtered_link.sh
	rm test/cases/compilation/output/multiple_source_build.sh
}

src_configure() {
	local mycmakeargs=(
		-DENABLE_UNIT_TESTS="$(usex test)"
		-DENABLE_FUNC_TESTS="$(usex test)"
	)
	cmake_src_configure
}

src_test() {
	if has sandbox "${FEATURES}"; then
		ewarn "FEATURES=sandbox detected"
		ewarn "Bear overrides LD_PRELOAD and conflicts with gentoo sandbox"
		ewarn "tests will fail"
	fi
	if has usersandbox "${FEATURES}"; then
		ewarn "FEATURES=usersandbox detected"
		ewarn "tests will fail"
	fi
	if
		has network-sandbox "${FEATURES}"; then
		ewarn "FEATURES=network-sandbox detected"
		ewarn "tests will fail"
	fi
	if
		has_version -b 'sys-devel/gcc-config[-native-symlinks]'; then
		ewarn "\'sys-devel/gcc-config[-native-symlinks]\' detected, tests call /usr/bin/cc directly (hardcoded)"
		ewarn "and will fail without generic cc symlink"
	fi

	export NVCC_APPEND_FLAGS="-ccbin gcc-12"

	einfo "test may use optional tools if found: gfortran libtool nvcc valgrind"
	# unit tests
	BUILD_DIR="${BUILD_DIR}/subprojects/Build/BearSource" cmake_src_test
	# functional tests
	BUILD_DIR="${BUILD_DIR}/subprojects/Build/BearTest" cmake_src_test
}
