# Copyright Gentoo Foundation
# Public domain

EAPI=7

PYTHON_COMPAT=( python{3_10,3_11} )
MULTILIB_COMPAT=( abi_x86_{32,64} )

inherit python-any-r1 git-r3 multilib-minimal flag-o-matic

DESCRIPTION="AMD Open Source Driver for Vulkan"
HOMEPAGE="https://github.com/GPUOpen-Drivers/AMDVLK"

RESTRICT="mirror"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="debug wayland"

COMMON_DEPEND=">=dev-util/vulkan-headers-1.1.130"

DEPEND="dev-util/cmake
	wayland? (
		dev-libs/wayland[${MULTILIB_USEDEP}]
	)
	${COMMON_DEPEND}"

RDEPEND="${PYTHON_DEPS}
	${COMMON_DEPEND}
	x11-libs/libdrm[${MULTILIB_USEDEP}]
	x11-libs/libXrandr[${MULTILIB_USEDEP}]
	virtual/libstdc++
	x11-libs/libxcb[${MULTILIB_USEDEP}]
	x11-libs/libxshmfence[${MULTILIB_USEDEP}]
	>=media-libs/vulkan-loader-1.1.130[${MULTILIB_USEDEP}]
	net-misc/curl
	wayland? (
		dev-libs/wayland[${MULTILIB_USEDEP}]
	)"

FETCH_URI="https://github.com/GPUOpen-Drivers"

src_unpack() {
	mkdir -p ${S}/drivers
	cd ${S}/drivers
	#for those who wants update ebuild: check https://github.com/GPUOpen-Drivers/AMDVLK/blob/master/default.xml
	#and place it in the constructions
	#Fetching: git-r3_fetch «repo» «commit»
	#Then placing it: git-r3_checkout «repo» «part»

	#xgl
	PART="xgl"
	COMMIT_ID="5ee2a33520138966eb5e2745dd3f2e5401d2f3b6"
	git-r3_fetch "${FETCH_URI}/${PART}" ${COMMIT_ID}
	git-r3_checkout "${FETCH_URI}/${PART}" ${S}/drivers/$PART

	#pal
	PART="pal"
	COMMIT_ID="9fab16015e522fff05890a045a1e9d8d3c23a636"
	git-r3_fetch "${FETCH_URI}/${PART}" ${COMMIT_ID}
	git-r3_checkout "${FETCH_URI}/${PART}" ${S}/drivers/$PART

	#pal
	PART="llpc"
	COMMIT_ID="93f91d8e6258aec02369b63c3248c9fab15c6956"
	git-r3_fetch "${FETCH_URI}/${PART}" ${COMMIT_ID}
	git-r3_checkout "${FETCH_URI}/${PART}" ${S}/drivers/$PART

	#spvgen
	PART="spvgen"
	COMMIT_ID="6c9a5cf8789681e31b9cd3df8af245b9aaa2c259"
	git-r3_fetch "${FETCH_URI}/${PART}" ${COMMIT_ID}
	git-r3_checkout "${FETCH_URI}/${PART}" ${S}/drivers/$PART

	#AMDVLK
	PART="AMDVLK"
	COMMIT_ID="813f090efbac744b56bbc96c3c0cc6e70f06ca50"
	git-r3_fetch "${FETCH_URI}/${PART}" ${COMMIT_ID}
	git-r3_checkout "${FETCH_URI}/${PART}" ${S}/drivers/$PART

	#LLVM. At this moment we had to download appropriate source code to build amdvlk.
	PART="llvm-project"
	COMMIT_ID="08268e9955d48ca075b239ae46328694ddff2413"
	git-r3_fetch "${FETCH_URI}/${PART}" ${COMMIT_ID}
	git-r3_checkout "${FETCH_URI}/${PART}" ${S}/drivers/$PART

	PART="MetroHash"
	COMMIT_ID="2b6fee002db6cc92345b02aeee963ebaaf4c0e2f"
	git-r3_fetch "${FETCH_URI}/${PART}" ${COMMIT_ID}
	git-r3_checkout "${FETCH_URI}/${PART}" ${S}/drivers/third_party/metrohash

	PART="CWPack"
	COMMIT_ID="b601c88aeca7a7b08becb3d32709de383c8ee428"
	git-r3_fetch "${FETCH_URI}/${PART}" ${COMMIT_ID}
	git-r3_checkout "${FETCH_URI}/${PART}" ${S}/drivers/third_party/cwpack
}

src_prepare() {
	cd ${S}/drivers
	eapply "${FILESDIR}/amdvlk-2019.3.5-GCC-9.patch"

	cat << EOF > "${T}/10-amdvlk-dri3.conf" || die
Section "Device"
Identifier "AMDgpu"
Option  "DRI" "3"
EndSection
EOF

	default
}

multilib_src_configure() {
	cd ${BUILD_DIR}

	ewarn "AMDVLK seems doesn't currently support avx:"
	ewarn "https://github.com/GPUOpen-Drivers/AMDVLK/issues/50"
	ewarn "append-flags -mno-avx -mno-avx2 -fstack-protector-strong -fno-plt"
	append-flags -mno-avx -mno-avx2 -fstack-protector-strong -fno-plt

	local mycmakeargs=()
	if use debug; then
		mycmakeargs+=( -DCMAKE_BUILD_TYPE=Debug )
	fi
	if use wayland; then
		mycmakeargs+=( -DBUILD_WAYLAND_SUPPORT=ON )
	fi

	cmake "${mycmakeargs[@]}" "${S}/drivers/xgl"
}

multilib_src_install() {
	if use abi_x86_64 && multilib_is_native_abi; then
		mkdir -p $D/usr/lib64/
		mv "${BUILD_DIR}/icd/amdvlk64.so" $D/usr/lib64/
		insinto /usr/share/vulkan/icd.d
		doins ${S}/drivers/AMDVLK/json/Redhat/amd_icd64.json
	else
		mkdir -p $D/usr/lib/
		mv "${BUILD_DIR}/icd/amdvlk32.so" $D/usr/lib/
		insinto /usr/share/vulkan/icd.d
		doins ${S}/drivers/AMDVLK/json/Redhat/amd_icd32.json
	fi
	einfo "json files installs to /usr/share/vulkan/icd.d instead of /etc because it shouldn't honor config-protect"
}

multilib_src_install_all(){
	insinto /usr/share/X11/xorg.conf.d/
	doins ${T}/10-amdvlk-dri3.conf
	einfo "AMDVLK Requires DRI3 so istalled /usr/share/X11/xorg.conf.d/10-amdvlk-dri3.conf"
	einfo "It's safe to double xorg configuration files if you have already had ones"
}

pkg_postinst() {
	elog "More information about the configuration can be found here:"
	elog " https://github.com/GPUOpen-Drivers/AMDVLK"
	ewarn "Make sure following line is NOT included in the any Xorg configuration section: "
	ewarn "Driver      \"modesetting\""
}
