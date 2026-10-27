# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{13..14} )

inherit distutils-r1 pypi
DESCRIPTION="Salt extension to implement Gentoo Linux support"
HOMEPAGE="https://salt-extensions.github.io/saltext-gentoo/"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
IUSE="test systemd"

BDEPEND="
		>=sys-apps/portage-3.0.82.2[${PYTHON_USEDEP}]
		!systemd? (
			>=app-admin/saltext-openrc-0.2.0[${PYTHON_USEDEP}]
		)
		test? (
			>=dev-python/pytest-salt-factories-1.0.5-r1
		)
"
EPYTEST_PLUGINS=()
distutils_enable_tests pytest
