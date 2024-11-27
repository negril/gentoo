# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: virtualx.eclass
# @MAINTAINER:
# x11@gentoo.org
# @AUTHOR:
# Original author: Martin Schlemmer <azarah@gentoo.org>
# @SUPPORTED_EAPIS: 7 8
# @BLURB: This eclass can be used for packages that need a working X environment to build.

if [[ -z ${_VIRTUALX_ECLASS} ]]; then
_VIRTUALX_ECLASS=1

case ${EAPI} in
	7|8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

inherit xdg-utils

# @ECLASS_VARIABLE: VIRTUALX_WM
# @PRE_INHERIT
# @DESCRIPTION:
# Variable specifying the window manager to start.
# Possible special values are "xvfb", "tinywl", "weston", "weston_xwayland"
# : "${VIRTUALX_WM:=( xvfb )}"
if [[ -z "${VIRTUALX_WM[*]}" ]] ; then
	VIRTUALX_WM=( xvfb )
fi

# @ECLASS_VARIABLE: VIRTUALX_REQUIRED
# @PRE_INHERIT
# @DESCRIPTION:
# Variable specifying the dependency on xorg-server and xhost.
# Possible special values are "always" and "manual", which specify
# the dependency to be set unconditionally or not at all.
# Any other value is taken as useflag desired to be in control of
# the dependency (eg. VIRTUALX_REQUIRED="kde" will add the dependency
# into "kde? ( )" and add kde into IUSE.
: "${VIRTUALX_REQUIRED:=test}"

# @ECLASS_VARIABLE: VIRTUALX_DEPEND
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# Standard dependencies string that is automatically added to BDEPEND
# unless VIRTUALX_REQUIRED is set to "manual".
# DEPRECATED: Pre-EAPI-8 you can specify the variable BEFORE inherit
# to add more dependencies.
[[ ${EAPI} != 7 ]] && VIRTUALX_DEPEND=""

_virtualx_check_virtualx_wm() {
	debug-print-function "${FUNCNAME[0]}" "$@"

	[[ $# -lt 2 ]] && die "${FUNCNAME[0]} needs at least two arguments"

	if has "$1" "${VIRTUALX_WM[@]}" && has "$2" "${VIRTUALX_WM[@]}"; then
		die "$1 and $2 are mutually exclusive"
	fi
}

_virtualx_check_virtualx_wm tinywl weston_xwayland
_virtualx_check_virtualx_wm weston weston_xwayland
_virtualx_check_virtualx_wm weston tinywl
_virtualx_check_virtualx_wm weston_xwayland xvfb

if has tinywl "${VIRTUALX_WM[@]}"; then
	VIRTUALX_DEPEND+="
		|| (
			gui-wm/tinywl
			<gui-libs/wlroots-0.17.3[tinywl(-)]
		)
	"
fi

if has weston "${VIRTUALX_WM[@]}"; then
	VIRTUALX_DEPEND+="
		dev-libs/weston[headless]
	"
fi

if has weston_xwayland "${VIRTUALX_WM[@]}"; then
	VIRTUALX_DEPEND+="
		dev-libs/weston[headless,xwayland]
	"
fi

if has xvfb "${VIRTUALX_WM[@]}"; then
	VIRTUALX_DEPEND+="
		x11-base/xorg-server[xvfb]
		x11-apps/xhost
	"
fi

[[ ${EAPI} != 7 ]] && readonly VIRTUALX_DEPEND

[[ ${VIRTUALX_COMMAND} ]] && die "VIRTUALX_COMMAND has been removed and is a no-op"

case ${VIRTUALX_REQUIRED} in
	manual)
		;;
	always)
		BDEPEND="${VIRTUALX_DEPEND}"
		;;
	*)
		BDEPEND="${VIRTUALX_REQUIRED}? ( ${VIRTUALX_DEPEND} )"
		IUSE="${VIRTUALX_REQUIRED}"
		[[ ${VIRTUALX_REQUIRED} == "test" ]] &&
			RESTRICT+=" !test? ( test )"
		;;
esac

# @ECLASS_VARIABLE: VIRTUALX_SKIP_ADDPREDICT
# @DESCRIPTION:
# Do not call addpredict.

# /var/db/repos/gentoo/gui-libs/gtk/gtk-4.14.4-r1.ebuild
# BDEPEND="
# 	test? (
# 		wayland? ( dev-libs/weston[headless] )
# 	)

# www-client/firefox/firefox-133.0.ebuild
# mail-client/thunderbird/thunderbird-128.5.0.ebuild
# BDEPEND="
# 	X? (
# 		sys-devel/gettext
# 		x11-base/xorg-server[xvfb]
# 		x11-apps/xhost
# 	)
# 	!X? (
# 		|| (
# 			gui-wm/tinywl
# 			<gui-libs/wlroots-0.17.3[tinywl(-)]
# 		)
# 		x11-misc/xkeyboard-config
# 	)
# 		if ! use X; then
# 			virtx_cmd=virtwl
# 		else
# 			virtx_cmd=virtx
# 		fi
# 	fi
#
# 	if ! use X; then
# 		local -x GDK_BACKEND=wayland
# 	else
# 		local -x GDK_BACKEND=x11
# 	fi
#
# 	${virtx_cmd} ./mach build --verbose || die
virtwl() {
	debug-print-function "${FUNCNAME[0]}" "$@"

	[[ $# -lt 1 ]] && die "${FUNCNAME[0]} needs at least one argument"
	[[ -n $XDG_RUNTIME_DIR ]] || die "${FUNCNAME[0]} needs XDG_RUNTIME_DIR to be set; try xdg_environment_reset"
	tinywl -h >/dev/null || die 'tinywl -h failed'

	local VIRTWL VIRTWL_PID
	coproc VIRTWL { WLR_BACKENDS=headless exec tinywl -s 'echo $WAYLAND_DISPLAY; read _; kill $PPID'; }
	local -x WAYLAND_DISPLAY
	read -r WAYLAND_DISPLAY <&"${VIRTWL[0]}"

	debug-print "${FUNCNAME[0]}: $*"
	nonfatal "$@"
	local r=$?

	[[ -n $VIRTWL_PID ]] || die "tinywl exited unexpectedly"
	exec {VIRTWL[0]}<&- {VIRTWL[1]}>&-
	return "$r"
}

# BDEPEND="test? ( wayland? ( dev-libs/weston[headless] ) )

# @FUNCTION: virtx
# @USAGE: <command> [command arguments]
# @DESCRIPTION:
# Start new Xvfb session and run commands in it.
#
# IMPORTANT: The command is run nonfatal !!!
#
# This means we are checking for the return code and raise an exception if it
# isn't 0. So you need to make sure that all commands return a proper
# code and not just die. All eclass function used should support nonfatal
# calls properly.
#
# The rational behind this is the tear down of the started Xfvb session. A
# straight die would leave a running session behind.
#
# Example:
#
# @CODE
# src_test() {
# 	virtx default
# }
# @CODE
#
# @CODE
# python_test() {
# 	virtx py.test --verbose
# }
# @CODE
#
# @CODE
# my_test() {
#   some_command
#   return $?
# }
#
# src_test() {
#   virtx my_test
# }
# @CODE

hardware_add_gpu_sandbox() {
	local dris cards WRITE=()

	# mesa will make use of udmabuf if it exists
	if [[ -c "/dev/udmabuf" ]]; then
		WRITE+=(
			"/dev/udmabuf"
		)
	fi

	# /dev/dri/card[%d]
	# /dev/dri/renderD[128+%d]
	readarray -t dris <<<"$(
		find /sys/class/drm/*/device/drm \
			-mindepth 1 -maxdepth 1 -type d -exec basename {} \; \
			| sort | uniq | sed 's:^:/dev/dri/:'
	)"

	[[ -n "${dris[*]}" ]] && WRITE+=( "${dris[@]}" )

	if [[ -d /sys/module/nvidia ]]; then
		# stat --printf="%Hr:%Lr"
		PREDICT+=(
			# /dev/char/195:X   # ../nvidiaX
			# /dev/char/195:254 # ../nvidia-modeset
			# /dev/char/195:255 # ../nvidiactl
			/dev/char/
		)

		# /dev/nvidia{0-9}
		readarray -t nvidia_devs <<<"$(
			find /dev -regextype posix-extended  -regex '/dev/nvidia(|-(nvswitch|vgpu))[0-9]*'
		)"
		[[ -n "${nvidia_devs[*]}" ]] && WRITE+=( "${nvidia_devs[@]}" )

		WRITE+=(
			"/dev/nvidiactl"
			# "/dev/nvidia-caps/nvidia-cap%d"
			"/dev/nvidia-caps/"

			# "/dev/nvidia-caps-imex-channels/channel%d"
			"/dev/nvidia-caps-imex-channels/"

			"/dev/nvidia-modeset"

			"/dev/nvidia-nvlink"
			"/dev/nvidia-nvswitchctl"

			"/dev/nvidia-uvm"
			"/dev/nvidia-uvm-tools"

			"/dev/nvidia-vgpuctl"
		)
	fi

	WRITE+=(
		# for portage
		"/proc/self/task/"
	)

	eqawarn "SANDBOX_WRITE   ${SANDBOX_WRITE//:/ }"
	eqawarn "SANDBOX_PREDICT ${SANDBOX_PREDICT//:/ }"

	local dev
	for dev in "${WRITE[@]}"; do
		if [[ ! -e "${dev}" ]]; then
			eqawarn "${dev} does not exist"
			continue
		fi

		if [[ -w "${dev}" ]]; then
			eqawarn "${dev} is already writable"
			continue
		fi

		eqawarn "${dev} addwrite"
		addwrite "${dev}"

		if [[ ! -d "${dev}" ]] && [[ ! -w "${dev}" ]]; then
			eerror "can not access ${dev} after addwrite"
		fi
	done

	local dev
	for dev in "${PREDICT[@]}"; do
		if [[ ! -e "${dev}" ]]; then
			eqawarn "${dev} does not exist"
			continue
		fi

		eqawarn "${dev} addpredict"
		addpredict "${dev}"
	done

	eqawarn "SANDBOX_WRITE   ${SANDBOX_WRITE//:/ }"
	eqawarn "SANDBOX_PREDICT ${SANDBOX_PREDICT//:/ }"
}

virtx() {
	debug-print-function "${FUNCNAME[0]}" "$@"

	[[ $# -lt 1 ]] && die "${FUNCNAME[0]} needs at least one argument"

	if has_version "media-libs/mesa[video_cards_zink]"; then
		eqawarn "mesa zink found"

		# eqawarn "using zink"
		# export MESA_LOADER_DRIVER_OVERRIDE=zink
	else
		eqawarn "mesa zink not found"
	fi

	export MESA_SHADER_CACHE_DISABLE=true

	_virtualx_check_XDG_RUNTIME_DIR() {
		# [[ -z $XDG_RUNTIME_DIR ]] && die "${FUNCNAME[0]} needs XDG_RUNTIME_DIR to be set; try xdg_environment_reset"

		if [[ -z $XDG_RUNTIME_DIR ]]; then
			eqawarn "${FUNCNAME[0]} with wayland needs XDG_RUNTIME_DIR to be set"

			eqawarn "running xdg_environment_reset"
			xdg_environment_reset
		fi
	}

	eqawarn "VIRTUALX_WM ${VIRTUALX_WM[*]}"

	hardware_add_gpu_sandbox

	if has tinywl "${VIRTUALX_WM[@]}" ; then
		_virtualx_check_XDG_RUNTIME_DIR
		tinywl -h >/dev/null || die 'tinywl -h failed'

		local VIRTWL VIRTWL_PID
		coproc VIRTWL { WLR_BACKENDS=headless exec tinywl -s 'echo $WAYLAND_DISPLAY; read _; kill $PPID'; }
		export WAYLAND_DISPLAY
		read -r WAYLAND_DISPLAY <&"${VIRTWL[0]}"
	fi

	if has weston "${VIRTUALX_WM[@]}" || has weston_xwayland "${VIRTUALX_WM[@]}"; then
		_virtualx_check_XDG_RUNTIME_DIR
		# TODO where does `wayland-7` come from
		local -x WAYLAND_DISPLAY=wayland-7

		local weston_opts=(
			--backend=headless-backend.so
			--socket="${WAYLAND_DISPLAY}"
			--idle-time=0
			--width=1280
			--height=1024
			--refresh-rate=144000 # mHz
		)
		if has weston_xwayland "${VIRTUALX_WM[@]}"; then
			weston_opts+=(
				--xwayland
			)
		fi
		weston "${weston_opts[@]}" &
		local compositor=$!
	fi

	if has xvfb "${VIRTUALX_WM[@]}"; then
		local xvfbargs=(
			-nolisten tcp
			-screen 0 1280x1024x24
			-noreset
			# +iglx
			# +xinerama
			# +extension RANDR
		)

		debug-print "${FUNCNAME[0]}: running Xvfb hack"
		# export XAUTHORITY= # done via xdg_environment_reset

		einfo "Starting Xvfb ..."

		# NOTE Calling addpredict in eclass scope will mask potential test failure causes.
		# So allow skipping it.
		if [[ ! -v VIRTUALX_SKIP_ADDPREDICT ]]; then
			addpredict /dev/dri/ # Needed for Xvfb w/ >=mesa-24.2.0
		elif [[ ! -v EGL_LOG_LEVEL ]]; then
			export EGL_LOG_LEVEL="fatal"
		fi

		debug-print "${FUNCNAME[0]}: Xvfb -displayfd 1 ${xvfbargs[*]}"
		local logfile="${T}/Xvfb.log"
		local pidfile="${T}/Xvfb.pid"
		# NB: bash command substitution blocks until Xvfb prints fd to stdout
		# and then closes the fd; only then it backgrounds properly
		local -x DISPLAY
		DISPLAY=":$(
			Xvfb -displayfd 1 "${xvfbargs[@]}" 2>"${logfile}" &
			echo "$!" > "${pidfile}"
		)"

		if [[ ${DISPLAY} == : ]]; then
			eerror "Xvfb failed to start, reprinting error log"
			cat "${logfile}"
			die "Xvfb failed to start"
		fi

		# Do not break on error, but setup $retval, as we need to kill Xvfb
		einfo "Xvfb started on DISPLAY=${DISPLAY}"
	fi

	debug-print "${FUNCNAME[0]}: $*"
	nonfatal "$@"
	local retval="$?"

	if has xvfb "${VIRTUALX_WM[@]}"; then
		# Now kill Xvfb
		kill "$(<"${pidfile}")" || die "Xvfb failed to stop"
	fi

	if has tinywl "${VIRTUALX_WM[@]}" ; then
		[[ -n $VIRTWL_PID ]] || die "tinywl exited unexpectedly"
		# TODO wat?
		exec {VIRTWL[0]}<&- {VIRTWL[1]}>&-
	fi

	if has weston "${VIRTUALX_WM[@]}" || has weston_xwayland "${VIRTUALX_WM[@]}"; then
		kill "${compositor}" || die
	fi

	# die if our command failed
	[[ ${retval} -ne 0 ]] && die -n "Command \"$*\" failed with exit status ${retval}"

	return "${retval}"
}

fi
