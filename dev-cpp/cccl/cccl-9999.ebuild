# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..12} )
LLVM_COMPAT=( {15..18} )
LLVM_OPTIONAL=true
inherit cmake cuda toolchain-funcs llvm-r1 python-any-r1

DESCRIPTION="CUDA C++ Core Libraries"
HOMEPAGE="https://github.com/NVIDIA/cccl"

if [[ ${PV} = *9999* ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/NVIDIA/${PN}.git"
else
	SRC_URI="
		https://github.com/NVIDIA/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	"
	KEYWORDS="~amd64"
fi

LICENSE="Apache-2.0"
SLOT="0"

# general options
IUSE="benchmarks cpp cub cuda cxx11 +cxx14 cxx17 cxx20 examples examples-filecheck libcudacxx multiconfig nvrtc  openmp rdc tbb thrust tuning test"

REQUIRED_USE="
	test? (
		${LLVM_REQUIRED_USE}
	)
"

RESTRICT="!test? ( test )"

# RDEPEND=""
# lit_dep="$(python_gen_any_dep '
# 	>=dev-python/lit-${LLVM_SLOT}[${PYTHON_USEDEP}]
# ')"

DEPEND="
	${RDEPEND}
	cuda? (
		dev-util/nvidia-cuda-toolkit:=
	)
	test? (
		dev-cpp/catch:=
		$(python_gen_any_dep '
			dev-python/lit[${PYTHON_USEDEP}]
		')
		$(llvm_gen_dep '
			>=dev-python/lit-${LLVM_SLOT}
		')
	)
"
# BDEPEND=""

# PATCHES=()

cuda_get_cuda_compiler() {
	local compiler
	tc-is-gcc && compiler="gcc"
	tc-is-clang && compiler="clang"
	[[ -z "$compiler" ]] && die "no compiler specified"

	local package="sys-devel/${compiler}"
	local version="${package}"
	local CUDAHOSTCXX_test
	while
		local CUDAHOSTCXX="${CUDAHOSTCXX_test}"
		version=$(best_version "${version}")
		if [[ -z "${version}" ]]; then
			if [[ -z "${CUDAHOSTCXX}" ]]; then
				die "could not find supported version of ${package}"
			fi
			break
		fi
		CUDAHOSTCXX_test="$(
			dirname "$(
				realpath "$(
					which "${compiler}-$(echo "${version}" | grep -oP "(?<=${package}-)[0-9]*")"
				)"
			)"
		)"
		version="<${version}"
	do ! echo "int main(){}" | nvcc "-ccbin ${CUDAHOSTCXX_test}" - -x cu &>/dev/null; done

	echo "${CUDAHOSTCXX}/c++"
}

cuda_get_host_native_arch() {
	: "${CUDAARCHS:=$(__nvcc_device_query)}"
	echo "${CUDAARCHS}"
}

pkg_pretend() {
	if use cuda && [[ -z "${CUDA_GENERATION}" ]] && [[ -z "${CUDA_ARCH_BIN}" ]]; then # TODO CUDAARCHS
		einfo "The target CUDA architecture can be set via one of:"
		einfo "  - CUDA_GENERATION set to one of Maxwell, Pascal, Volta, Turing, Ampere, Lovelace, Hopper, Auto"
		einfo "  - CUDA_ARCH_BIN, (and optionally CUDA_ARCH_PTX) in the form of x.y tuples."
		einfo "      You can specify multiple tuple separated by \";\"."
		einfo ""
		einfo "The CUDA architecture tuple for your device can be found at https://developer.nvidia.com/cuda-gpus."
	fi

	if use cuda && [[ ${MERGE_TYPE} == "buildonly" ]] && [[ -n "${CUDA_GENERATION}" || -n "${CUDA_ARCH_BIN}" ]]; then
		local info_message="When building a binary package it's recommended to unset CUDA_GENERATION and CUDA_ARCH_BIN"
		einfo "$info_message so all available architectures are build."
	fi

	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp
}

pkg_setup() {
	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp
	python-any-r1_pkg_setup
}

src_prepare() {
	use test && llvm-r1_pkg_setup
	cmake_src_prepare
}

src_configure() {
	local FORCE_RDC="yes"

	local mycmakeargs=(
		# -DMIN_VER_CMAKE=3.26

		-DCMAKE_POLICY_DEFAULT_CMP0148="OLD" # FindPythonInterp

		# Enable CUDA C++ Core Library benchmarks.
		-DCCCL_ENABLE_BENCHMARKS="$(usex benchmarks)"

		# Enable the CUB developer build.
		-DCCCL_ENABLE_CUB="$(usex cub)"

		# Enable CUDA C++ Core Library examples.
		-DCCCL_ENABLE_EXAMPLES="$(usex examples)"

		# Enable installation of CCCL.
		-DCCCL_ENABLE_INSTALL_RULES="yes"

		# Enable the libcu++ developer build.
		-DCCCL_ENABLE_LIBCUDACXX="$(usex libcudacxx)"

		# Enable CUDA C++ Core Library tests.
		-DCCCL_ENABLE_TESTING="$(usex test)"

		# Enable the Thrust developer build.
		-DCCCL_ENABLE_THRUST="$(usex thrust)"
	)
	if use benchmarks; then
		mycmakeargs+=(
			-DCMAKE_BUILD_TYPE="Release"
		)
	fi

	if use cub; then
		mycmakeargs+=(
			# Use CUDA CURAND library
			-DCUB_C2H_ENABLE_CURAND="yes"

			# Build CUB benchmarking suite.
			-DCUB_ENABLE_BENCHMARKS="$(usex benchmarks)"

			# Generate C++11 build configurations.
			-DCUB_ENABLE_DIALECT_CPP11="$(usex cxx11)"

			# Generate C++14 build configurations.
			-DCUB_ENABLE_DIALECT_CPP14="$(usex cxx14)"

			# Generate C++17 build configurations.
			-DCUB_ENABLE_DIALECT_CPP17="$(usex cxx17)"

			# Generate C++20 build configurations.
			-DCUB_ENABLE_DIALECT_CPP20="$(usex cxx20)"

			# Build CUB examples.
			-DCUB_ENABLE_EXAMPLES="$(usex examples)"

			# Test that all public headers compile.
			-DCUB_ENABLE_HEADER_TESTING="$(usex test)"

			# Enable installation of CUB
			# -DCUB_ENABLE_INSTALL_RULES=ON

			# Build CUB testing suite.
			-DCUB_ENABLE_TESTING="$(usex test)"

			# Build CUB tuning suite.
			-DCUB_ENABLE_TUNING="$(usex tuning)"

			# Suppress warnings about deprecated Thrust/CUB API.
			# -DCUB_IGNORE_DEPRECATED_API=OFF

			# Build each catch2 test as a separate executable.
			-DCUB_SEPARATE_CATCH2="yes"
		)

		if use cxx11; then
			mycmakeargs+=(
				-DTHRUST_IGNORE_DEPRECATED_CPP_DIALECT="yes"
			)
		fi
		if use test; then
			mycmakeargs+=(
				# Enable tests that require separable compilation.
				-DCUB_ENABLE_RDC_TESTS="$(usex rdc)"

				# Enable separable compilation on all targets that support it.
				-DCUB_FORCE_RDC="${FORCE_RDC}"
			)
		fi
	fi

	if use libcudacxx; then
		mycmakeargs+=(
			# Enable the CUDA language support.
			-DLIBCUDACXX_ENABLE_CUDA="$(usex cuda)"

			# Enable libcu++ tests.
			-DLIBCUDACXX_ENABLE_LIBCUDACXX_TESTS="$(usex test)"

			# Executor to use when running tests.
			# -DLIBCUDACXX_EXECUTOR=None

			# TargetInfo to use when setting up test environment.
			# -DLIBCUDACXX_TARGET_INFO=libcudacxx.test.target_info.LocalTI

			# Enable test timeouts (Default = 200, Off = 0)
			-DLIBCUDACXX_TEST_TIMEOUT="0"

			# Enable ctest-based testing.
			-Dlibcudacxx_ENABLE_CMAKE_TESTS="no"
			# -Dlibcudacxx_ENABLE_CMAKE_TESTS="$(usex test)"

			# Enable ctest-based testing.
			-Dlibcudacxx_ENABLE_CODEGEN="no"

			# Enable installation of libcudacxx
			# -Dlibcudacxx_ENABLE_INSTALL_RULES=ON

			# Parallelism used to run libcudacxx's lit test suite.
			-Dlibcudacxx_LIT_PARALLEL_LEVEL="$(nproc)"
		)

		if use test; then
			mycmakeargs+=(
				# Test libcu++ with runtime compilation instead of offline compilation. Only runs device side tests.
				-DLIBCUDACXX_TEST_WITH_NVRTC="$(usex nvrtc)"
			)
		fi
	fi

	if use thrust; then
		if use multiconfig; then
			mycmakeargs+=(
				# Generate build configurations for all C++ standards supported by the configured compilers.
				# -DTHRUST_MULTICONFIG_ENABLE_DIALECT_ALL:BOOL=OFF

				# Generate C++11 build configurations.
				-DTHRUST_MULTICONFIG_ENABLE_DIALECT_CPP11="$(usex cxx11)"

				# Generate C++14 build configurations.
				-DTHRUST_MULTICONFIG_ENABLE_DIALECT_CPP14="$(usex cxx14)"

				# Generate C++17 build configurations.
				-DTHRUST_MULTICONFIG_ENABLE_DIALECT_CPP17="$(usex cxx17)"

				# Generate C++20 build configurations.
				-DTHRUST_MULTICONFIG_ENABLE_DIALECT_CPP20="$(usex cxx20)"

				# Generate a single build configuration for the most recent C++ standard supported by the configured compilers.
				# -DTHRUST_MULTICONFIG_ENABLE_DIALECT_LATEST="yes"

				# Generate build configurations that use CPP.
				-DTHRUST_MULTICONFIG_ENABLE_SYSTEM_CPP="$(usex cpp)"

				# Generate build configurations that use CUDA.
				-DTHRUST_MULTICONFIG_ENABLE_SYSTEM_CUDA="$(usex cuda)"

				# Generate build configurations that use OpenMP.
				-DTHRUST_MULTICONFIG_ENABLE_SYSTEM_OMP="$(usex openmp)"

				# Generate build configurations that use TBB.
				-DTHRUST_MULTICONFIG_ENABLE_SYSTEM_TBB="$(usex tbb)"

				# Limit host/device configs: SMALL (up to 3 h/d combos per dialect), MEDIUM(6), LARGE(8), FULL(12)
				-DTHRUST_MULTICONFIG_WORKLOAD="SMALL"
			)
		else
			local THRUST_DEVICE_SYSTEM THRUST_HOST_SYSTEM

			THRUST_DEVICE_SYSTEM="CPP"
			THRUST_HOST_SYSTEM="CPP"

			if use openmp; then
				THRUST_DEVICE_SYSTEM="OMP"
				THRUST_HOST_SYSTEM="OMP"
			fi
			if use tbb; then
				THRUST_DEVICE_SYSTEM="TBB"
				THRUST_HOST_SYSTEM="TBB"
			fi
			if use cuda; then
				THRUST_DEVICE_SYSTEM="CUDA"
				THRUST_HOST_SYSTEM="CPP"
			fi

			mycmakeargs+=(
				# Thrust device system. # CUDA CPP OMP TBB
				-DTHRUST_DEVICE_SYSTEM="${THRUST_DEVICE_SYSTEM}"

				# Thrust host system. # CPP OMP TBB
				-DTHRUST_HOST_SYSTEM="${THRUST_HOST_SYSTEM}"
			)

			local CPP_DIALECT
			use cxx11 && CPP_DIALECT="11"
			use cxx14 && CPP_DIALECT="14"
			use cxx17 && CPP_DIALECT="17"
			use cxx20 && CPP_DIALECT="20"
			mycmakeargs+=(
				# The C++ standard to target: 11;14;17;20
				-DTHRUST_CPP_DIALECT="${CPP_DIALECT}"
			)
		fi

		mycmakeargs+=(
			# Build Thrust examples.
			-DTHRUST_ENABLE_EXAMPLES="$(usex examples)"

			# Check example output with the LLVM FileCheck utility.
			-DTHRUST_ENABLE_EXAMPLE_FILECHECK="$(usex examples "$(usex examples-filecheck)")"

			# Test that all public headers compile.
			-DTHRUST_ENABLE_HEADER_TESTING="$(usex header "$(usex test)")"

			# Enable installation of Thrust
			# -DTHRUST_ENABLE_INSTALL_RULES=ON

			# Enable multiconfig options for coverage testing.
			-DTHRUST_ENABLE_MULTICONFIG="$(usex multiconfig)"

			# Build Thrust testing suite.
			-DTHRUST_ENABLE_TESTING="$(usex test)"
		)
		if use test; then
			mycmakeargs+=(
				# Enable tests that require separable compilation.
				-DTHRUST_ENABLE_RDC_TESTS="$(usex rdc)"

				# Enable separable compilation on all targets that support it.
				-DTHRUST_FORCE_RDC="${FORCE_RDC}"
			)

			if use examples; then
				mycmakeargs+=(
					# Build CUB tests and examples. (Requires CUDA).
					# -DTHRUST_INCLUDE_CUB_CMAKE="$(usex cuda)"
					-DTHRUST_INCLUDE_CUB_CMAKE="no"
				)
			fi
		fi
	fi

	if use cuda; then
		cuda_add_sandbox -w
		addwrite "/proc/self/task"
		CUDAHOSTCXX="$(cuda_get_cuda_compiler)"
		CUDAARCHS="$(cuda_get_host_native_arch)"
		export CUDAHOSTCXX
		export CUDAARCHS
		mycmakeargs+=(
			-DLIBCUDACXX_COMPUTE_ARCHS="${CUDAARCHS}"
		)
	fi

	# local -x CPM_USE_LOCAL_PACKAGES="yes"
	local -x CPM_LOCAL_PACKAGES_ONLY="yes"
	cmake_src_configure
}

src_test() {
	use cuda && cuda_add_sandbox -w

	CMAKE_SKIP_TESTS=(
		"libcudacxx.test.lit$"
		"thrust.test.async.*.simple"
	)
	myctestargs=(
		# -j1
		--output-on-failure
		--timeout 7200
		# -R '(thrust.test.async.exclusive_scan.simple|thrust.test.async.inclusive_scan.simple)$'
	)

	cmake_src_test
}
