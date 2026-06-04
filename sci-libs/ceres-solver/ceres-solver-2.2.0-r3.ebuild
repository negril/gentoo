# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )
DOCS_BUILDER="sphinx"
DOCS_DEPEND="dev-python/sphinx-rtd-theme"
DOCS_DIR="docs/source"
inherit cmake-multilib cuda flag-o-matic python-any-r1 docs

DESCRIPTION="Nonlinear least-squares minimizer"
HOMEPAGE="http://ceres-solver.org/ https://github.com/ceres-solver/ceres-solver"

if [[ ${PV} = *9999* ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/ceres-solver/ceres-solver.git"
else
	SRC_URI="
		https://github.com/ceres-solver/ceres-solver/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz
		http://ceres-solver.org/${P}.tar.gz
	"
	KEYWORDS="~amd64 ~x86"
fi

LICENSE="sparse? ( BSD ) !sparse? ( LGPL-2.1 )"
SLOT="0/1"
IUSE="examples cuda gflags lapack metis +schur sparse test"

REQUIRED_USE="test? ( gflags ) sparse? ( lapack ) abi_x86_32? ( !sparse !lapack )"
RESTRICT="!test? ( test )"

BDEPEND="${PYTHON_DEPS}
	lapack? ( virtual/pkgconfig )
	doc? ( <dev-libs/mathjax-3 )
"
RDEPEND="
	>=dev-cpp/eigen-3.3.4:=
	dev-cpp/glog:=[gflags?,${MULTILIB_USEDEP}]
	cuda? ( dev-util/nvidia-cuda-toolkit:= )
	lapack? ( virtual/lapack )
	sparse? (
		sci-libs/amd
		sci-libs/camd
		sci-libs/ccolamd
		sci-libs/cholmod[metis(+)]
		sci-libs/colamd
		sci-libs/spqr
	)
"
DEPEND="${RDEPEND}"

DOCS=( README.md VERSION )

PATCHES=(
	"${FILESDIR}/${PN}-2.0.0-system-mathjax.patch"
	"${FILESDIR}/${PN}-2.2.0-include-algorithm.patch"
	"${FILESDIR}/${PN}-2.2.0-eigen-5.patch"
)

src_prepare() {
	cmake_src_prepare

	filter-lto

	# search paths work for prefix
	sed -e "s:/usr:${EPREFIX}/usr:g" \
		-i cmake/*.cmake || die

	# remove Werror
	sed \
		-e 's/-Werror=(all|extra)//g' \
		-e '/set(CMAKE_CUDA_ARCHITECTURES/s/")/" CACHE STRING "")/' \
		-i CMakeLists.txt || die
}

src_configure() {
	# CUSTOM_BLAS=OFF EIGENSPARSE=OFF MINIGLOG=OFF
	local mycmakeargs=(
		-DBUILD_BENCHMARKS=OFF
		-DBUILD_DOCUMENTATION="$(usex doc)"
		-DBUILD_EXAMPLES="$(usex examples)"
		-DBUILD_SHARED_LIBS="yes"
		-DBUILD_TESTING="$(usex test)"

		-DEIGENMETIS="$(usex metis)"
		-DEIGENSPARSE="$(usex sparse)"
		-DGFLAGS="$(usex gflags)"
		-DLAPACK="$(usex lapack)"
		-DMINIGLOG="no"
		-DSUITESPARSE="$(usex sparse)"
		-DCUSTOM_BLAS="yes"
		-DEigen3_DIR="${ESYSROOT}/usr/$(get_libdir)/cmake/eigen3"

		-DSCHUR_SPECIALIZATIONS="$(usex schur)"
		-DUSE_CUDA="$(usex cuda)"
	)

	if use cuda; then
		cuda_add_sandbox
		addpredict "/dev/char/"

		: "${CUDAHOSTCXX:=$(cuda_gccdir)}"
		: "${CUDAARCHS:=all}"
		export CUDAHOSTCXX
		export CUDAARCHS
	fi

	if use !sparse ; then
		mycmakeargs+=(
			-DEIGENSPARSE="yes"
		)
	fi

	cmake-multilib_src_configure
}

src_test() {
	use cuda && cuda_add_sandbox -w

	cmake-multilib_src_test
}

src_install() {
	cmake-multilib_src_install

	if use examples; then
		docompress -x "/usr/share/doc/${PF}/examples"
		dodoc -r examples data
	fi
}
