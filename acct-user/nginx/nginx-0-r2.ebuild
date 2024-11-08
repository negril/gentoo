# Copyright 2019-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit acct-user

ACCT_USER_ID="82"
ACCT_USER_GROUPS=( "nginx" )
ACCT_USER_HOME="/var/lib/nginx"

IUSE="icingaweb2"

acct-user_add_deps

RDEPEND+="
	icingaweb2? (
		acct-group/icingacmd
		acct-group/icingaweb2
	)
"

pkg_setup() {
	# www-apps/icingaweb2
	use icingaweb2 && ACCT_USER_GROUPS+=( icingacmd icingaweb2 )
}
