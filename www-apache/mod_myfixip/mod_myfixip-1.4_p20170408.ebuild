# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit depend.apache apache-module

EGIT_COMMIT="fb87a168643d4db7cb4cf8784e16c2ae151b5831"

DESCRIPTION="Fix remote_ip in HTTP/HTTPS using the PROXY protocol"

HOMEPAGE="https://github.com/ggrandes/apache24-modules/"
SRC_URI="https://github.com/ggrandes/apache24-modules/archive/${EGIT_COMMIT}.tar.gz -> ${PN}-1.4_p20170408.tar.gz"
S="${WORKDIR}/apache24-modules-${EGIT_COMMIT}"

LICENSE="Apache-2.0"

SLOT="0"
KEYWORDS="~amd64 ~x86"

APACHE2_MOD_CONF="00_${PN}"

DOCFILES="README.md"

need_apache2

pkg_setup() {
	# Calling depend.apache_pkg_setup fails because we do not have
	# "apache2" in IUSE but the function expects this in order to call
	# _init_apache2_late which sets the APACHE_MODULESDIR variable.
	_init_apache2
	_init_apache2_late
}
