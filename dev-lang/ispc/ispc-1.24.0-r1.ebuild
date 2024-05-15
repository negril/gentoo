# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

LLVM_COMPAT=( {17..18} )
PYTHON_COMPAT=( python3_{10..13} )

inherit cmake llvm-r1 multiprocessing python-any-r1 toolchain-funcs

DESCRIPTION="Intel SPMD Program Compiler"
HOMEPAGE="
	https://ispc.github.io/
	https://github.com/ispc/ispc/
"
SRC_URI="
	https://github.com/ispc/ispc/archive/v${PV}.tar.gz
		-> ${P}.gh.tar.gz
"

LICENSE="BSD BSD-2 UoI-NCSA"
SLOT="0"
KEYWORDS="~amd64 ~arm ~arm64 ~ppc64 ~x86"
ISPC_LLVM_TARGETS=(
	ARM # we force this on arm
	WebAssembly # TODO needs dev-util/emscripten
	X86 # we force this on x86
	XE
)
ISPC_LLVM_TARGETS=( "${ISPC_LLVM_TARGETS[@]/#/+llvm_targets_}" )
IUSE="cross examples l0 openmp test utils ${ISPC_LLVM_TARGETS[*]}"
RESTRICT="!test? ( test )"

RDEPEND="
	$(llvm_gen_dep '
		sys-devel/clang:${LLVM_SLOT}
	')
	sys-libs/ncurses:=
	l0? ( dev-libs/level-zero:= )
	llvm_targets_XE? (
		dev-util/intel-graphics-compiler
	)
	!openmp? ( dev-cpp/tbb:= )
"
DEPEND="
	${RDEPEND}
	test? ( dev-cpp/gtest )
"
BDEPEND="
	app-alternatives/yacc
	app-alternatives/lex
	${PYTHON_DEPS}
"

PATCHES=(
	"${FILESDIR}/${PN}-1.24.0-ignore-git.patch"
)

pkg_pretend() {
	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp
}

pkg_setup() {
	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp
	llvm-r1_pkg_setup
	python-any-r1_pkg_setup
}

src_prepare() {
	if use amd64; then
		# On amd64 systems, build system enables x86/i686 build too.
		# This ebuild doesn't even have multilib support, nor need it.
		# https://bugs.gentoo.org/730062
		einfo "Removing auto-x86 build on amd64"
		sed -i -e 's:set(target_arch "i686"):return():' cmake/GenerateBuiltins.cmake || die
	fi

	# do not require bundled gtest
	mkdir -p ispcrt/tests/vendor/google/googletest || die
	cat > ispcrt/tests/vendor/google/googletest/CMakeLists.txt <<-EOF || die
		find_package(GTest)
	EOF

	# do not require bundled benchmark
	mkdir -p benchmarks/vendor/google/benchmark || die
	cat > benchmarks/vendor/google/benchmark/CMakeLists.txt <<-EOF || die
		find_package(benchmark)
	EOF

	# remove hacks that break unbundling
	sed -i -e '/gmock/d' -e '/install/,$d' ispcrt/tests/CMakeLists.txt || die

	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DCMAKE_SKIP_RPATH=ON
		-DISPC_CROSS="$(usex "cross")"
		-DISPC_INCLUDE_EXAMPLES="$(usex "examples")"
		-DISPC_INCLUDE_TESTS=$(usex test)
		-DISPC_INCLUDE_UTILS="$(usex "utils")"
		-DISPCRT_BUILD_GPU="$(usex "l0")"
		-DISPCRT_BUILD_TASK_MODEL=$(usex openmp OpenMP TBB)

		-DWASM_ENABLED="$(usex "llvm_targets_WebAssembly")"
		-DXE_ENABLED="$(usex "llvm_targets_XE")"
	)

	if use llvm_targets_XE; then
		mycmakeargs+=( -DLLVMSPIRVLibPath="$(get_llvm_prefix)/$(get_libdir)/libLLVMSPIRVLib.so" )
	fi

	if use amd64 || use x86 || use llvm_targets_X86 ; then
		mycmakeargs+=( -DX86_ENABLED="yes" )
	else
		mycmakeargs+=( -DX86_ENABLED="no" )
	fi

	if use arm || use arm64 || use llvm_targets_ARM ; then
		mycmakeargs+=( -DARM_ENABLED="yes" )
	else
		mycmakeargs+=( -DARM_ENABLED="no" )
	fi

	cmake_src_configure
}

src_test() {
	# Inject path to prevent using system ispc
	local -x PATH="${BUILD_DIR}/bin:${PATH}"
	"${EPYTHON}" ./run_tests.py "-j$(makeopts_jobs)" -v ||
		die "Testing failed under ${EPYTHON}"
}

src_install() {
	cmake_src_install

	if use examples; then
		docompress -x /usr/share/doc/${PF}/examples
		dodoc -r examples
	fi
}
