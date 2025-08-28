# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# TODO
# --Ofast-compile=<level>

# @ECLASS: cuda.eclass
# @MAINTAINER:
# Gentoo Science Project <sci@gentoo.org>
# @SUPPORTED_EAPIS: 7 8
# @BLURB: Common functions for cuda packages
# @DESCRIPTION:
# This eclass contains functions to be used with cuda package. Currently it is
# setting and/or sanitizing NVCCFLAGS, the compiler flags for nvcc. This is
# automatically done and exported in src_prepare() or manually by calling
# cuda_sanitize.
# @EXAMPLE:
# inherit cuda

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_CUDA_ECLASS} ]]; then
_CUDA_ECLASS=1

inherit edo flag-o-matic toolchain-funcs

# @ECLASS_VARIABLE: CUDA_REQUIRED_USE
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# Requires at least one NVPTX target to be compiled.
# Example use for CUDA libraries:
# @CODE
# REQUIRED_USE="${CUDA_REQUIRED_USE}"
# @CODE
# Example use for packages that depend on CUDA libraries:
# @CODE
# IUSE="cuda"
# REQUIRED_USE="cuda? ( ${CUDA_REQUIRED_USE} )"
# @CODE

# @ECLASS_VARIABLE: CUDA_USEDEP
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# This is an eclass-generated USE-dependency string which can be used to
# depend on another CUDA package being built for the same NVPTX architecture.
#
# The generated USE-flag list is compatible with packages using cuda.eclass.
#
# Example use:
# @CODE
# DEPEND="media-libs/opencv[${CUDA_USEDEP}]"
# @CODE

# @ECLASS_VARIABLE: CUDA_SKIP_GLOBALS
# @DESCRIPTION:
# Controls whether _cuda_set_globals() is executed. This variable is for
# ebuilds that call check_nvptx() without the need to define nvptx_targets_*
# USE-flags.
#
# Example use:
# @CODE
# CUDA_SKIP_GLOBALS=1
# inherit cuda
# @CODE

# @FUNCTION: _cuda_set_globals
# @DESCRIPTION:
# Set global variables useful to ebuilds: IUSE, CUDA_REQUIRED_USE, and
# CUDA_USEDEP, unless CUDA_SKIP_GLOBALS is set.
# https://arnon.dk/matching-sm-architectures-arch-and-gencode-for-various-nvidia-cards/

_cuda_set_globals() {
	# [[ -n ${CUDA_SKIP_GLOBALS} ]] && return

# cutlass/CMakeList.txt
# if (CUDA_VERSION VERSION_GREATER_EQUAL 11.4)
#   list(APPEND CUTLASS_NVCC_ARCHS_SUPPORTED 70 72 75 80 86 87)
# endif()
# if (CUDA_VERSION VERSION_GREATER_EQUAL 11.8)
#   list(APPEND CUTLASS_NVCC_ARCHS_SUPPORTED 89 90)
# endif()
# if (CUDA_VERSION VERSION_GREATER_EQUAL 12.0)
#   list(APPEND CUTLASS_NVCC_ARCHS_SUPPORTED 90a)
# endif()
#
# if (CUDA_VERSION VERSION_GREATER_EQUAL 12.8)
#   list(APPEND CUTLASS_NVCC_ARCHS_SUPPORTED 100 100a 101 101a 120 120a)
# endif()

	if [[ -n ${CUDA_DEVICE_TARGETS} ]]; then
		local nvptx_device_targets_11_8=(
			# Kepler
			35 37
		)

		local nvptx_device_targets=(
			"${nvptx_device_targets_11_8[@]}"
			# Maxwell
			50 52 53
			# Pascal
			60 61 62
			# Volta
			70 72
			# Turing
			75
			# Ampere
			80 86 87
			# Ada Lovelace
			89
			# Hopper
			90 90a
			# # Blackwell
			# 100 10x
			# 10.
			103 103f 103a

			#12.1
			121
		)

		local nvptx_named_targets=(
			all
			all-major
			native
		)

		IUSE="${nvptx_device_targets[*]/#/nvptx_targets_sm_} ${nvptx_device_targets[*]/#/nvptx_targets_compute_} +${nvptx_named_targets[*]/#/nvptx_targets_}"

		CUDA_REQUIRED_USE="
			?? (
				|| (
					${nvptx_device_targets[*]/#/nvptx_targets_sm_}
					${nvptx_device_targets[*]/#/nvptx_targets_compute_}
				)
				${nvptx_named_targets[*]/#/nvptx_targets_}
			)
		"

		local all_nvptx_targets=(
			"${nvptx_device_targets[@]/#/nvptx_targets_sm_}"
			"${nvptx_device_targets[@]/#/nvptx_targets_compute_}"
			"${nvptx_named_targets[@]/#/nvptx_targets_}"
		)

		local optflags="${all_nvptx_targets[*]/%/(-)?}"
		CUDA_USEDEP=${optflags// /,}

		for target in "${nvptx_device_targets_11_8[@]/#/nvptx_targets_sm_}" "${nvptx_device_targets_11_8[@]/#/nvptx_targets_compute_}"; do
			DEPEND+=" $(printf "%s? ( <dev-util/nvidia-cuda-toolkit-12.0 )" "${target}")"
		done
	fi
}

_cuda_set_globals
unset -f _cuda_set_globals

# == old stuff ==

# @ECLASS_VARIABLE: NVCCFLAGS
# @DESCRIPTION:
# nvcc compiler flags (see nvcc --help), which should be used like
# CFLAGS for c compiler
: "${NVCCFLAGS:=-O2}"

# @ECLASS_VARIABLE: CUDA_VERBOSE
# @DESCRIPTION:
# Being verbose during compilation to see underlying commands
: "${CUDA_VERBOSE:=false}"

# @ECLASS_VARIABLE: CUDA_SETGCC
# @DESCRIPTION:
# Set compiler dir in cuda_sanitize.
: "${CUDA_SETGCC:=false}"

# @FUNCTION: cuda_get_host_compiler
# @USAGE: [-f]
# @RETURN: compiler name compatible with current cuda
# @DESCRIPTION:
# Helper for determination of the latest compiler supported by
# then current nvidia cuda toolkit.
# NVCC_CCBIN is the variable used by nvcc.
# https://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/#nvcc-environment-variables
# CUDAHOSTCXX is the variable used by cmake.
# https://cmake.org/cmake/help/latest/variable/CMAKE_LANG_HOST_COMPILER.html
cuda_get_host_compiler() {
	if [[ -v NVCC_CCBIN ]]; then
		echo "${NVCC_CCBIN}"
		return
	fi

	if [[ -v CUDAHOSTCXX ]]; then
		echo "${CUDAHOSTCXX}"
		return
	fi

	einfo "Trying to find working CUDA host compiler"

	if ! tc-is-gcc && ! tc-is-clang; then
		die "$(tc-get-compiler-type) compiler is not supported (use gcc or clang)"
	fi

	local compiler compiler_type compiler_version
	local package package_version
	local NVCC_CCBIN_default

	compiler_type="$(tc-get-compiler-type)"
	compiler_version="$("${compiler_type}-major-version")"

	# try the default compiler first
	NVCC_CCBIN="$(tc-getCXX)"
	NVCC_CCBIN_default="${NVCC_CCBIN}-${compiler_version}"

	compiler="${NVCC_CCBIN/%-${compiler_version}}"

	# store the package so we can re-use it later
	package="sys-devel/${compiler_type}"
	package_version="${package}"

	ebegin "testing ${NVCC_CCBIN_default} (default)"

	while ! nvcc -v -ccbin "${NVCC_CCBIN}" - -x cu <<<"int main(){}" &>> "${T}/cuda_get_host_compiler.log" ; do
		eend 1

		while true; do
			# prepare next version
			if ! package_version="<$(best_version "${package_version}")"; then
				die "could not find a supported version of ${compiler}"
			fi

			NVCC_CCBIN="${compiler}-$(ver_cut 1 "${package_version/#<${package}-/}")"

			[[ "${NVCC_CCBIN}" != "${NVCC_CCBIN_default}" ]] && break
		done
		ebegin "testing ${NVCC_CCBIN}"
	done
	eend $?

	# clean temp file
	nonfatal rm -f a.out

	echo "${NVCC_CCBIN}"
	export NVCC_CCBIN

	einfo "Using ${NVCC_CCBIN} to build (via ${package} iteration)"
}

cuda_get_host_native_arch() {
	if [[ -n ${CUDAARCHS} ]]; then
		echo "${CUDAARCHS}"
		return
	fi

	if ! SANDBOX_WRITE=/dev/nvidiactl test -w /dev/nvidiactl ; then
		eerror
		eerror "Can not access the GPU at /dev/nvidiactl."
		eerror "User $(id -nu) is not in the group \"video\"."
		eerror
		ewarn
		ewarn "Can not query the native device."
		ewarn "Not setting CUDAARCHS."
		ewarn
		ewarn "Continuing with default value."
		ewarn "Set CUDAARCHS manually if needed."
		ewarn
		return 1
	fi

	__nvcc_device_query || eerror "failed to query the native device"
}

# @FUNCTION: cuda_gccdir
# @USAGE: [-f]
# @RETURN: gcc bindir compatible with current cuda, optionally (-f) prefixed with "--compiler-bindir "
# @DESCRIPTION:
# Helper for determination of the latest gcc bindir supported by
# then current nvidia cuda toolkit.
#
# Example:
# @CODE
# cuda_gccdir -f
# -> --compiler-bindir "/usr/x86_64-pc-linux-gnu/gcc-bin/4.6.3"
# @CODE
cuda_gccdir() {
	debug-print-function "${FUNCNAME[0]}" "$@"

	local dirs gcc_bindir ver flag

	while [[ "$1" ]]; do
		case $1 in
			-f)
				flag="-ccbin "
				;;
			*)
				;;
		esac
		shift
	done

	if ! cuda_get_host_compiler >/dev/null; then
		eerror "Could not execute cuda-config"
	fi
	if [[ -z ${NVCC_CCBIN} ]]; then
		die "Could not determine supported compiler versions from cuda-config"
	fi

	if [[ -n ${NVCC_CCBIN} ]]; then
		if [[ -n ${flag} ]]; then
			echo "${flag}$(type -p "${NVCC_CCBIN}")"
		else
			echo "${NVCC_CCBIN}"
		fi
		return 0
	else # BUG
		eerror "Only gcc version(s) ${vers} are supported,"
		eerror "of which none is installed"
		die "Only gcc version(s) ${vers} are supported"
		return 1
	fi
}

# @FUNCTION: cuda_sanitize
# @DESCRIPTION:
# Correct NVCCFLAGS by adding the necessary reference to gcc bindir and
# passing CXXFLAGS to underlying compiler without disturbing nvcc.
cuda_sanitize() {
	debug-print-function "${FUNCNAME[0]}"

	local rawldflags=$(raw-ldflags)
	# Be verbose if wanted
	[[ "${CUDA_VERBOSE}" == true ]] && NVCCFLAGS+=" -v"

	# Tell nvcc where to find a compatible compiler
	[[ "${CUDA_SETGCC}" == true ]] && NVCCFLAGS+=" $(cuda_gccdir -f)"

	# Tell nvcc which flags should be used for underlying C compiler
	NVCCFLAGS+=" --compiler-options \"${CXXFLAGS}\" --linker-options \"${rawldflags// /,}\""

	debug-print "Using ${NVCCFLAGS} for cuda"
	export NVCCFLAGS
}

# 	addpredict "/dev/char/"
# 	test -c /dev/udmabuf && addwrite /dev/udmabuf
# 	test -c /dev/dri/card0 && addwrite /dev/dri/card0
# 	test -c /dev/dri/renderD128 && addwrite /dev/dri/renderD128
# 	test -c /dev/nvidiactl && addwrite /dev/nvidiactl
# 	test -c /dev/nvidia-uvm && addwrite /dev/nvidia-uvm
# 	test -c /dev/nvidia-uvm-tools && addwrite /dev/nvidia-uvm-tools
# 	test -c /dev/nvidia0 && addwrite /dev/nvidia0
# 	test -c /dev/nvidia-modeset && addwrite /dev/nvidia-modeset

# @FUNCTION: cuda_add_sandbox
# @USAGE: [-w]
# @DESCRIPTION:
# Add nvidia dev nodes to the sandbox predict list.
# with -w, add to the sandbox write list.
cuda_add_sandbox() {
	debug-print-function "${FUNCNAME[0]}" "$@"

	# /dev/char/195:0 -> ../nvidia0
	# /dev/char/195:254 -> ../nvidia-modeset
	# /dev/char/195:255 -> ../nvidiactl
	# /dev/char/226:0 -> ../dri/card0
	# /dev/char/226:128 -> ../dri/renderD128
	# /dev/char/240:0 -> ../nvidia-uvm
	# /dev/char/240:1 -> ../nvidia-uvm-tools
	# /dev/char/245:1 -> ../nvidia-caps/nvidia-cap1
	# /dev/char/245:2 -> ../nvidia-caps/nvidia-cap2

	# edo nvidia-smi -L
	# if [[ ! -d /sys/module/nvidia ]]; then
	# 	einfo "loading nvidia module"
	# 	nvidia-modprobe || die
	# fi
  #
	# if [[ ! -d /sys/module/nvidia_uvm ]]; then
	# 	einfo "loading nvidia_uvm module"
	# 	nvidia-modprobe -u || die
	# fi

	local i WRITE

	# /dev/dri/card*
	# /dev/dri/renderD*
	# readarray -t dri <<<"$(find /sys/module/nvidia/drivers/*/*:*:*.*/drm -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sed 's:^:/dev/dri/:')"
	readarray -t dri <<<"$(find /sys/class/drm -maxdepth 1 -regextype  egrep -regex ".*/(card|renderD)[0-9]*" -exec basename {} \; | sed 's:^:/dev/dri/:')"

	# /dev/nvidia{0-9}
	readarray -t cards <<<"$(find /dev -regextype sed -regex '/dev/nvidia[0-9]*')"

	WRITE+=(
		"${dri[@]}"
		"${cards[@]}"
		/dev/nvidiactl
		/dev/nvidia-uvm*

		# for portage
		/proc/self/task/
	)
	# for i in "${WRITE[@]}"; do
	# 	einfo "addwrite $i"
	# 	addwrite "$i"
	# done

	PREDICT=(
		/dev/char/
		# /root
		# /dev/crypto
		# /var/cache/man
		# /var/cache/fontconfig
		# /proc/self/maps
		# /dev/console
		# /dev/random
		# /proc/self/task/
	)
	for i in "${PREDICT[@]}"; do
		einfo "addpredict $i"
		addpredict "$i"
	done

	for i in "${WRITE[@]}" ; do
		if [[ $1 == '-w' ]]; then
			einfo "addwrite $i"
			addwrite "$i"
		else
			einfo "addpredict $i"
			addpredict "$i"
		fi
	done
}

# @FUNCTION: cuda_toolkit_version
# @DESCRIPTION:
# echo the installed version of dev-util/nvidia-cuda-toolkit
cuda_toolkit_version() {
	debug-print-function "${FUNCNAME[0]}" "$@"

	local v
	v="$(best_version dev-util/nvidia-cuda-toolkit)"
	v="${v##*cuda-toolkit-}"
	ver_cut 1-2 "${v}"
}

# @FUNCTION: cuda_cudnn_version
# @DESCRIPTION:
# echo the installed version of dev-libs/cudnn
cuda_cudnn_version() {
	debug-print-function "${FUNCNAME[0]}" "$@"

	local v
	v="$(best_version dev-libs/cudnn)"
	v="${v##*cudnn-}"
	ver_cut 1-2 "${v}"
}

cuda_pkg_pretend() {
	if [[ $(tc-get-cxx-stdlib) == "libc++" ]] ; then
		eerror "CUDA requires glibc"
		die "CUDA requires glibc"
	fi

	if [[ -z "${CUDA_GENERATION}" ]] && [[ -z "${CUDA_ARCH_BIN}" ]]; then # TODO CUDAARCHS
		einfo "The target CUDA architecture can be set via one of:"
		einfo "  - CUDA_GENERATION set to one of Maxwell, Pascal, Volta, Turing, Ampere, Lovelace, Hopper, Auto"
		einfo "  - CUDA_ARCH_BIN, (and optionally CUDA_ARCH_PTX) in the form of x.y tuples."
		einfo "      You can specify multiple tuple separated by \";\"."
		einfo ""
		einfo "The CUDA architecture tuple for your device can be found at https://developer.nvidia.com/cuda-gpus."
	fi

	# When building binpkgs you probably want to include all targets
	if [[ ${MERGE_TYPE} == "buildonly" ]] && [[ -n "${CUDA_GENERATION}" || -n "${CUDA_ARCH_BIN}" ]]; then
		local info_message="When building a binary package it's recommended to unset CUDA_GENERATION and CUDA_ARCH_BIN"
		einfo "$info_message so all available architectures are build."
	fi
}

cuda_pkg_setup() {
	if [[ ! -e /dev/nvidia-uvm ]]; then
		# NOTE We try to load nvidia-uvm and nvidia-modeset here,
		# so __nvcc_device_query does not fail later.

		# we use nvidia-smi as it creates all dev files when run
		nvidia-smi -L >/dev/null || true
	fi
}

# @FUNCTION: cuda_src_prepare
# @DESCRIPTION:
# Sanitise and export NVCCFLAGS by default
cuda_src_prepare() {
	debug-print-function "${FUNCNAME[0]}" "$@"

	cuda_sanitize

	# NOTE Append some useful summary here # TODO
	cat >> "${CMAKE_USE_DIR}"/CMakeLists.txt <<- _EOF_ || die

		message(STATUS "<<< Gentoo CUDA configuration >>>
			Compiler         \${CMAKE_CUDA_COMPILER}
			Host Compiler    \${CMAKE_CUDA_HOST_COMPILER}
			Compiler flags:
			CMAKE_CUDA_FLAGS \${CMAKE_CUDA_FLAGS}
			CMAKE_CUDA_FLAGS_\${CMAKE_BUILD_TYPE} \${CMAKE_CUDA_FLAGS_\${CMAKE_BUILD_TYPE}}
			Architectures    \${CMAKE_CUDA_ARCHITECTURES}\n")
	_EOF_
}

cuda_src_configure() {
	cuda_add_sandbox -w
	addwrite "/proc/self/task"
	addpredict "/dev/char"

	if [[ ! -w /dev/nvidiactl ]]; then
		# eqawarn "Can't access the GPU at /dev/nvidiactl."
		# eqawarn "User $(id -nu) is not in the group \"video\"."
		if [[ -z "${CUDA_GENERATION}" ]] && [[ -z "${CUDA_ARCH_BIN}" ]]; then
			# build all targets
			mycmakeargs+=(
				-DCUDA_GENERATION=""
			)
		fi
	else
		local -x CUDAARCHS
		: "${CUDAARCHS:="$(cuda_get_host_native_arch)"}"
	fi

	# set NVCC_CCBIN
	local -x CUDAHOSTCXX CUDAHOSTLD
	CUDAHOSTCXX="$(cuda_get_host_compiler)"
	CUDAHOSTLD="$(tc-getCXX)"
	export NVCC_CCBIN="${CUDAHOSTCXX}"

	if tc-is-gcc; then
		# Filter out IMPLICIT_LINK_DIRECTORIES picked up by CMAKE_DETERMINE_COMPILER_ABI(CUDA)
		# See /usr/share/cmake/Help/variable/CMAKE_LANG_IMPLICIT_LINK_DIRECTORIES.rst
		CMAKE_CUDA_IMPLICIT_LINK_DIRECTORIES_EXCLUDE=$(
			"${CUDAHOSTLD}" -E -v - <<<"int main(){}" |& \
			grep LIBRARY_PATH | cut -d '=' -f 2 | cut -d ':' -f 1
		)
	fi
}

cuda_src_test() {
	local WRITE=()

	# mesa via virtx will make use of udmabuf if it exists
	[[ -c "/dev/udmabuf" ]] && WRITE+=( "/dev/udmabuf" )

	readarray -t dris <<<"$(
		for dri in /sys/class/drm/*/dev; do
			realpath "/dev/char/$(cat "${dri}")"
			eqawarn "dri ${dri} $(cat "${dri}") $(realpath "/dev/char/$(cat "${dri}")")"
		done
	)"

	[[ -n "${dris[*]}" ]] && WRITE+=( "${dris[@]}" )

	if [[ -d /sys/module/nvidia ]]; then
		# /dev/nvidia{0-9}
		readarray -t nvidia_devs <<<"$(
			find /dev -regextype posix-extended  -regex '/dev/nvidia(|-(nvswitch|vgpu))[0-9]*'
		)"
		[[ -n "${nvidia_devs[*]}" ]] && WRITE+=( "${nvidia_devs[@]}" )

		WRITE+=(
			"/dev/nvidiactl"
			"/dev/nvidia-modeset"

			"/dev/nvidia-vgpuctl"

			"/dev/nvidia-nvlink"
			"/dev/nvidia-nvswitchctl"

			"/dev/nvidia-uvm"
			"/dev/nvidia-uvm-tools"

			# "/dev/nvidia-caps/nvidia-cap%d"
			"/dev/nvidia-caps/"
			# "/dev/nvidia-caps-imex-channels/channel%d"
			"/dev/nvidia-caps-imex-channels/"
		)
	fi

	# for portage
	WRITE+=( "/proc/self/task/" )

	local dev
	for dev in "${WRITE[@]}"; do
		[[ ! -e "${dev}" ]] && return

		[[ -w "${dev}" ]] && return

		eqawarn "addwrite ${dev}"
		addwrite "${dev}"
		if [[ ! -d "${dev}" ]] && [[ ! -w "${dev}" ]]; then
			eerror "can not access ${dev} after addwrite"
		fi
	done
}

fi

EXPORT_FUNCTIONS pkg_pretend pkg_setup src_prepare src_configure src_test
