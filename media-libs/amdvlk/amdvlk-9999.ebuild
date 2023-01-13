# Copyright
#

EAPI=7

DESCRIPTION="AMD Open Source Driver for Vulkan"
HOMEPAGE="https://github.com/GPUOpen-Drivers/AMDVLK"

LICENSE=""
SLOT="9999"
KEYWORDS="~amd64"
IUSE=""

DEPEND="dev-util/repo"
RDEPEND="x11-libs/libdrm"

BUILD_DIR="${S}/drivers/xgl/builds/Release64"

src_unpack() {
	mkdir ${S}
	cd ${S}
	repo init -u https://github.com/GPUOpen-Drivers/AMDVLK.git -b master
	repo sync
}

src_configure() {
	cd "${S}/drivers/xgl"
	cmake -H. -Bbuilds/Release64
}

src_compile() {
	cd ${BUILD_DIR}
	make
}

src_install() {
	dolib.so "${BUILD_DIR}/icd/amdvlk64.so"

	insinto /etc/vulkan/icd.d
	doins ${S}/drivers/AMDVLK/json/Redhat/amd_icd64.json
}

pkg_postinst() {
        elog "More information about the configuration can be found here:"
        elog "  https://github.com/GPUOpen-Drivers/AMDVLK"
}


