# Copyright 2020-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{13..14} )
DISTUTILS_USE_PEP517=setuptools

inherit distutils-r1

DESCRIPTION="The new generation of the pytest-salt Plugin"
HOMEPAGE="
	https://github.com/saltstack/pytest-salt-factories/
	https://pypi.org/project/pytest-salt-factories/
"
SRC_URI="
	https://github.com/saltstack/pytest-salt-factories/archive/${PV//_/}.tar.gz
		-> ${P}.gh.tar.gz
"
S=${WORKDIR}/${P//_/}

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	dev-python/attrs[${PYTHON_USEDEP}]
	dev-python/docker[${PYTHON_USEDEP}]
	dev-python/psutil[${PYTHON_USEDEP}]
	>=dev-python/pytest-7.0.0[${PYTHON_USEDEP}]
	dev-python/pytest-helpers-namespace[${PYTHON_USEDEP}]
	dev-python/pytest-skip-markers[${PYTHON_USEDEP}]
	dev-python/pytest-system-statistics[${PYTHON_USEDEP}]
	>=dev-python/pytest-shell-utilities-1.4.0[${PYTHON_USEDEP}]
	dev-python/pyzmq[${PYTHON_USEDEP}]
	dev-python/msgpack[${PYTHON_USEDEP}]
	dev-python/virtualenv[${PYTHON_USEDEP}]
	>=app-admin/salt-3008.2[${PYTHON_USEDEP}]
"
BDEPEND="
	dev-python/setuptools-scm[${PYTHON_USEDEP}]
	test? (
		dev-python/importlib-metadata[${PYTHON_USEDEP}]
		dev-python/pyfakefs[${PYTHON_USEDEP}]
		dev-python/pytest-subtests[${PYTHON_USEDEP}]
	)
"

EPYTEST_PLUGIN_LOAD_VIA_ENV=1
EPYTEST_PLUGINS=(
	"helpers_namespace"
	"pytester"
	"pytest_helpers_namespace.plugin"
	"pytest_subtests"
	"pytestsysstats.plugin"
	"saltfactories.plugins"
	"saltfactories.plugins.factories"
	"saltfactories.plugins.markers"
	"saltfactories.plugins.sysinfo"
	"saltfactories.plugins.event_listener"
	"saltfactories.plugins.log_server"
	"saltfactories.plugins.loader"
)
distutils_enable_tests pytest

export SETUPTOOLS_SCM_PRETEND_VERSION=${PV}

src_prepare() {
	distutils-r1_src_prepare
}

python_test() {
	local EPYTEST_DESELECT=(
		"tests/functional/test_manager.py::test_system_service_cli[system-service(True)]"
		"tests/functional/test_manager.py::test_system_service_config_fixture[system-service(True)]"
		"tests/integration/factories/daemons/ssh/test_salt_ssh.py::test_salt_ssh"
		"tests/integration/factories/daemons/sshd/test_sshd.py::test_connect"
		"tests/scenarios/examples/test_echoext.py::test_echoext"
	)

	local ret tempdir
	# ${T} is too long a path for the tests to work
	tempdir="$(mktemp -du --tmpdir=/tmp salt-XXX)" || die
	addwrite "${tempdir}"

	local -x SHELL="/bin/bash" TMPDIR="${tempdir}"

	nonfatal epytest --no-sys-stats
	ret=${?}

	rm -rf "${tempdir}" || die
	[[ ${ret} -ne 0 ]] && die "Tests failed with ${EPYTHON}"
}
