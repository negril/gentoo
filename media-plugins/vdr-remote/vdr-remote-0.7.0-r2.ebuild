# Copyright 2021-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit vdr-plugin-2

DESCRIPTION="VDR Plugin: use various devices for controlling vdr (keyboards, lirc...)"
HOMEPAGE="http://www.escape-edv.de/endriss/vdr/"
SRC_URI="http://www.escape-edv.de/endriss/vdr/${P}.tgz"

SLOT="0"
LICENSE="GPL-2"
KEYWORDS="amd64 x86"
IUSE="systemd"

DEPEND="
	>=media-video/vdr-2.2.0
"
RDEPEND="
	${DEPEND}
	systemd? ( acct-user/vdr[remote] )
"
