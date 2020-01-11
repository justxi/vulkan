# Copyright Gentoo Foundation
# Public domain

EAPI=6

PYTHON_COMPAT=( python{3_4,3_5,3_6,3_7} )
MULTILIB_COMPAT=( abi_x86_{32,64} )

inherit python-any-r1 git-r3 multilib-minimal flag-o-matic

DESCRIPTION="AMD Open Source Driver for Vulkan"
HOMEPAGE="https://github.com/GPUOpen-Drivers/AMDVLK"

RESTRICT="mirror"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="debug wayland"

COMMEN_DEPEND=">=dev-util/vulkan-headers-1.1.129"

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
	>=media-libs/vulkan-loader-1.1.129[${MULTILIB_USEDEP}]
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
	COMMIT_ID="7e13a8bd0bb57d3cfb3bc014f6b26a8c9bb8bfd9"
	git-r3_fetch "${FETCH_URI}/${PART}" ${COMMIT_ID}
	git-r3_checkout "${FETCH_URI}/${PART}" ${S}/drivers/$PART

	#pal
	PART="pal"
	COMMIT_ID="40af910391fb8c287cb37bf520c41310bf88d405"
	git-r3_fetch "${FETCH_URI}/${PART}" ${COMMIT_ID}
	git-r3_checkout "${FETCH_URI}/${PART}" ${S}/drivers/$PART

	#pal
	PART="llpc"
	COMMIT_ID="2efe41812964c88aa38a80c66939ce44ae493fd4"
	git-r3_fetch "${FETCH_URI}/${PART}" ${COMMIT_ID}
	git-r3_checkout "${FETCH_URI}/${PART}" ${S}/drivers/$PART

	#spvgen
	PART="spvgen"
	COMMIT_ID="ce06cb5e3116ba77a22c3278dfeadfd865a8977c"
	git-r3_fetch "${FETCH_URI}/${PART}" ${COMMIT_ID}
	git-r3_checkout "${FETCH_URI}/${PART}" ${S}/drivers/$PART

	#AMDVLK
	PART="AMDVLK"
	COMMIT_ID="e6d1928269b75ee6b31c69bef185be104f39ca88"
	git-r3_fetch "${FETCH_URI}/${PART}" ${COMMIT_ID}
	git-r3_checkout "${FETCH_URI}/${PART}" ${S}/drivers/$PART

	#LLVM. At this moment we had to download appropriate source code to build amdvlk.
	PART="llvm-project"
	COMMIT_ID="cc0df5ace776584f5f7c0c20704d28f445f0e074"
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
