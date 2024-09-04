# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_EXT=1
DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{10..12} )

inherit distutils-r1

DESCRIPTION="Accelerate module for PyOpenGL"
HOMEPAGE="
	https://pyopengl.sourceforge.net/
	https://github.com/mcfletch/pyopengl/
	https://pypi.org/project/PyOpenGL-accelerate/"

if [[ ${PV} = *9999* ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/mcfletch/pyopengl.git"
else
	MY_P=pyopengl-release-${PV}
	SRC_URI="
		https://github.com/mcfletch/pyopengl/archive/release-${PV}.tar.gz
			-> ${MY_P}.gh.tar.gz
	"
	KEYWORDS="amd64 x86 ~amd64-linux ~x86-linux"
fi
S=${WORKDIR}/${MY_P}/accelerate

LICENSE="BSD"
SLOT="0"
IUSE="numpy"

DEPEND="
	numpy? (
		dev-python/numpy:0/0=[${PYTHON_USEDEP}]
	)
"
RDEPEND="
	${DEPEND}
	dev-python/pyopengl[${PYTHON_USEDEP}]
"
BDEPEND="
	dev-python/cython[${PYTHON_USEDEP}]
"

distutils_enable_tests pytest

src_prepare() {
	default

	[[ ${PV} != *9999* ]] && eapply -p2 "${FILESDIR}/${PN}-3.1.7-gcc-14.patch"
}

src_configure() {
	rm src/*.c || die

	if ! use numpy; then
		cat > "${T}"/numpy.py <<-EOF || die
			raise ImportError("building numpy extension disabled")
		EOF
	fi
}

python_compile() {
	local -x PYTHONPATH=${T}:${PYTHONPATH}
	distutils-r1_python_compile
}

python_test() {
	cd "${T}" || die
	epytest "${S}"/tests
}
