# Copyright 2019-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit acct-user

ACCT_USER_ID="82"
ACCT_USER_GROUPS=( "nginx" )
ACCT_USER_HOME="/var/lib/nginx"

IUSE="icinga mailgraph"

acct-user_add_deps

pkg_setup() {
	# www-apps/icingaweb2
	use icinga && ACCT_USER_GROUPS+=( icingacmd icingaweb2 )

	# net-mail/mailgraph
	use mailgraph && ACCT_USER_GROUPS+=( mgraph )
}
