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
	>=app-admin/salt-3008.2[${PYTHON_USEDEP}]
	dev-python/attrs[${PYTHON_USEDEP}]
	dev-python/docker[${PYTHON_USEDEP}]
	dev-python/psutil[${PYTHON_USEDEP}]
	dev-python/pyzmq[${PYTHON_USEDEP}]
	dev-python/msgpack[${PYTHON_USEDEP}]
	dev-python/virtualenv[${PYTHON_USEDEP}]
"
BDEPEND="
	dev-python/setuptools-scm[${PYTHON_USEDEP}]
	test? (
		dev-python/importlib-metadata[${PYTHON_USEDEP}]
		dev-python/pyfakefs[${PYTHON_USEDEP}]
	)
"

# EPYTEST_XDIST=1
# ValueError: Plugin already registered under a different name:
EPYTEST_PLUGIN_LOAD_VIA_ENV=1
EPYTEST_PLUGINS=(
	"${PN}"
	"pytest-helpers-namespace"
	"pytest-shell-utilities"
	"pytest-skip-markers"
	"pytest-system-statistics"
)
distutils_enable_tests pytest

src_prepare() {
	# fails with unknown helpers_namespace otherwise
	sed -i -e 's#helpers_namespace#pytest_&.plugin#' tests/conftest.py || die

	distutils-r1_src_prepare
}

src_compile() {
	SETUPTOOLS_SCM_PRETEND_VERSION="${PV}" distutils-r1_src_compile
}

python_test() {
	local EPYTEST_DESELECT=(
		"tests/functional/utils/saltext/test_log_handlers.py::test_all_messages_received"
		"tests/integration/factories/daemons/minion/test_minion.py::test_no_match"
		"tests/integration/factories/daemons/proxy/test_proxy_minion.py::test_no_match"

		"tests/integration/factories/daemons/sshd/test_sshd.py::test_connect"
		"tests/scenarios/examples/test_echoext.py::test_echoext"
	)

	local EPYTEST_IGNORE=(
		# tries to connect to docker
		"tests/functional/factories/daemons/test_container_factory.py"
		"tests/integration/factories/daemons/container/test_container_factory.py"

		"tests/integration/factories/daemons/container/test_master.py"
		"tests/integration/factories/daemons/container/test_minion.py"
		"tests/integration/factories/daemons/ssh/test_salt_ssh.py"

		"tests/integration/factories/cli/test_salt.py"

		# Skipping until we devote time to fix syndic support
		"tests/integration/factories/daemons/syndic/test_syndic.py"
	)

	local ret
	# ${T} is too long a path for the tests to work
	local -x TMPDIR
	TMPDIR="$(mktemp -d --tmpdir=/tmp salt-XXX || die)"
	addwrite "${TMPDIR}"

	local -x SHELL="/bin/bash"

	nonfatal epytest --no-sys-stats
	ret=${?}

	rm -rf "${TMPDIR}" || die
	[[ ${ret} -ne 0 ]] && die "Tests failed with ${EPYTHON}"
}
