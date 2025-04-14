# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="LLVM-based OpenCL compiler for OpenCL targetting Intel <Gen7 graphics hardware"
HOMEPAGE="https://github.com/intel/compute-runtime"

LICENSE="MIT"
SLOT="legacy"
KEYWORDS="~amd64"

DEPEND="${CATEGORY}/${PN//-legacy}:${SLOT}"
RDEPEND="${DEPEND}"
