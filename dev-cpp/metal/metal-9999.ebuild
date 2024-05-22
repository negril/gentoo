# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

LLVM_COMPAT=( {16..18} )
inherit cmake llvm-r1

DESCRIPTION="Love template metaprogramming"
HOMEPAGE="https://brunocodutra.github.io/metal/"

if [[ ${PV} = *9999* ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/brunocodutra/${PN}.git"
else
	SRC_URI="
		https://github.com/brunocodutra/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	"
	KEYWORDS="~amd64"
fi

LICENSE="MIT"
SLOT="0"

# general options
IUSE="doc examples test"

# REQUIRED_USE=""

RESTRICT="!test? ( test )"

# RDEPEND=""
DEPEND="
	${RDEPEND}
	examples? (
		dev-libs/boost:=
	)
	test? (
		dev-util/cppcheck
		$(llvm_gen_dep '
			sys-devel/clang:${LLVM_SLOT}
		')
	)
"
BDEPEND="
	doc? (
		app-text/doxygen
	)
"

# PATCHES=()

pkg_setup(){
	llvm-r1_pkg_setup
}

src_prepare() {
	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DMETAL_BUILD_DOC="$(usex doc)"
		-DMETAL_BUILD_EXAMPLES="$(usex examples)"
		-DMETAL_BUILD_TESTS="$(usex test)"

		# -DCMAKE_DISABLE_FIND_PACKAGE_Doxygen="$(usex !doc)"
	)

	# local -x CPM_USE_LOCAL_PACKAGES="yes"
	# local -x CPM_LOCAL_PACKAGES_ONLY="yes"
	cmake_src_configure
}

src_test() {
	local CTESTS=(
		# (Failed)
		"test.formatting.metal.config.version$" # 224
		"test.formatting.metal.config$"         # 225
		"test.formatting.metal.detail.sfinae$"  # 227
		"test.formatting.metal.detail$"         # 228
		"test.formatting.metal.value.distinct$" # 320
		"test.formatting.metal.value$"          # 327
		"test.formatting.metal$"                # 328
	)
	CMAKE_SKIP_TESTS=(
		"^example."
	)
	myctestargs=(
		# -R '('$( IFS='|'; echo "${CTESTS[*]}")')'
		--output-on-failure
		-j1

	)
	cmake_src_test
}
