# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# TODO
# - multilib? Why?

PYTHON_COMPAT=( python3_{12..14} )
DOCS_BUILDER="sphinx"
DOCS_DEPEND="dev-python/sphinx-rtd-theme"
DOCS_DIR="docs/source"
inherit cmake-multilib cuda python-any-r1 docs

DESCRIPTION="Nonlinear least-squares minimizer"
HOMEPAGE="http://ceres-solver.org/ https://github.com/ceres-solver/ceres-solver"

if [[ ${PV} = *9999* ]] ; then
	inherit git-r3
	EGIT_SUBMODULES=()
	EGIT_REPO_URI="https://github.com/ceres-solver/ceres-solver.git"
else
	if [[ ${PV} == *_pre* ]] ; then
		COMMIT="0c70ed3a1a2d6ba47c06c7e8b3b040880bc474db"
		SRC_URI="
			https://github.com/ceres-solver/ceres-solver/archive/${COMMIT}.tar.gz -> ${P}.tar.gz
		"
		S="${WORKDIR}/${PN}-${COMMIT}"
	else
		SRC_URI="
			https://github.com/ceres-solver/ceres-solver/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz
			http://ceres-solver.org/${P}.tar.gz
		"
	fi
	KEYWORDS="~amd64 ~x86"
fi

LICENSE="sparse? ( BSD ) !sparse? ( LGPL-2.1 )"
# SONAME
SLOT="0/4"
# TODO openmp? tbb?
IUSE="+eigen examples cuda lapack metis +schur sparse test"

REQUIRED_USE="
	|| ( eigen sparse )
	sparse? (
		lapack
	)
	abi_x86_32? (
		!sparse
		!lapack
	)
"
# 	test? ( gflags )
# "

RESTRICT="!test? ( test )"

BDEPEND="${PYTHON_DEPS}
	lapack? (
		virtual/pkgconfig
	)
	doc? (
		dev-libs/mathjax
	)
"
# dev-cpp/abseil-cpp is exported in CeresConfig.cmake
RDEPEND="
	dev-cpp/abseil-cpp:=
	cuda? (
		dev-util/nvidia-cuda-toolkit:=
	)
	eigen? (
		>=dev-cpp/eigen-3.3.4:=
		metis? (
			sci-libs/metis
		)
	)
	sparse? (
		sci-libs/amd
		sci-libs/camd
		sci-libs/ccolamd
		sci-libs/cholmod[cuda=,metis(+)]
		sci-libs/colamd
		sci-libs/spqr[cuda(-)=]
	)
	lapack? (
		virtual/lapack
	)
"

DEPEND="${RDEPEND}"

DOCS=( README.md CITATION.cff )

PATCHES=(
	"${FILESDIR}/${PN}-2.0.0-system-mathjax.patch"
	"${FILESDIR}/${PN}-2.3.0-CUDAARCHS.patch"
)

src_prepare() {
	cmake_src_prepare

	# search paths work for prefix
	sed -e "s:/usr:${EPREFIX}/usr:g" \
		-i cmake/*.cmake || die

	# Tries to find ../../data from tests. Which doesn't work with out of source build.
	# Create symlink to not have to touch the source code
	ln -rs "${S}/data" "${WORKDIR}/data" || die

	# remove Werror
	sed \
		-e 's/-Werror=(all|extra)//g' \
		-i CMakeLists.txt || die
}

src_configure() {
	# CUSTOM_BLAS=OFF EIGENSPARSE=OFF MINIGLOG=OFF
	local mycmakeargs=(
		-DBUILD_BENCHMARKS="no"
		-DBUILD_DOCUMENTATION="$(usex doc)"
		-DBUILD_EXAMPLES="$(usex examples)"
		-DBUILD_SHARED_LIBS="yes"
		-DBUILD_TESTING="$(usex test)"

		# TODO sort out the eigen/sparse interaction. Are they exclusive?
		-DEIGENMETIS="$(usex eigen "$(usex metis)")"
		-DEIGENSPARSE="$(usex eigen)"
		-DLAPACK="$(usex lapack)"
		-DSUITESPARSE="$(usex sparse)"

		-DSCHUR_SPECIALIZATIONS="$(usex schur)"

		-DCUSTOM_BLAS="$(usex !eigen)"

		-DPROVIDE_UNINSTALL_TARGET="no"

		-DUSE_CUDA="$(usex cuda)"

		# -DBLAS_*
		# -DMETIS_*
		# -DSuiteSparse_*
	)

	if use cuda ; then
		cuda_add_sandbox
		addpredict "/dev/char/"

		: "${CUDAHOSTCXX:=$(cuda_gccdir)}"
		: "${CUDAARCHS:=all}"
		export CUDAHOSTCXX
		export CUDAARCHS
	fi

	if use eigen ; then
		mycmakeargs+=(
			-DEigen3_DIR="${ESYSROOT}/usr/$(get_libdir)/cmake/eigen3"
		)
	fi

	cmake-multilib_src_configure
}

src_test() {
	if use cuda ; then
		cuda_add_sandbox -w
	fi

	cmake-multilib_src_test
}

src_install() {
	cmake-multilib_src_install

	if use examples ; then
		docompress -x "/usr/share/doc/${PF}/examples"
		dodoc -r examples data
	fi
}
