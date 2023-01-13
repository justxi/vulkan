# Copyright Gentoo Foundation
# Public domain

EAPI=7

PYTHON_COMPAT=( python{3_6,3_7,3_8,3_9} )
MULTILIB_COMPAT=( abi_x86_{32,64} )

inherit python-any-r1 git-r3 multilib-minimal flag-o-matic

DESCRIPTION="AMD Open Source Driver for Vulkan"
HOMEPAGE="https://github.com/GPUOpen-Drivers/AMDVLK"

RESTRICT="mirror"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="debug wayland"

DEPEND="dev-util/cmake
	wayland? (
		dev-libs/wsa[${MULTILIB_USEDEP}]
	)
	>=dev-util/vulkan-headers-1.1.127"

RDEPEND="${PYTHON_DEPS}
	x11-libs/libdrm[${MULTILIB_USEDEP}]
	x11-libs/libXrandr[${MULTILIB_USEDEP}]
	virtual/libstdc++
	x11-libs/libxcb[${MULTILIB_USEDEP}]
	x11-libs/libxshmfence[${MULTILIB_USEDEP}]
	>=dev-util/vulkan-headers-1.1.119
	>=media-libs/vulkan-loader-1.1.119[${MULTILIB_USEDEP}]
	net-misc/curl
	wayland? (
		dev-libs/wsa[${MULTILIB_USEDEP}]
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
	COMMIT_ID="83c89cd727653c4514e2abe30e1633220fdb666e"
	git-r3_fetch "${FETCH_URI}/${PART}" ${COMMIT_ID}
	git-r3_checkout "${FETCH_URI}/${PART}" ${S}/drivers/$PART

	#pal
	PART="pal"
	COMMIT_ID="5d72cf9890fe2fbb1b87eecc497114e04afaa277"
	git-r3_fetch "${FETCH_URI}/${PART}" ${COMMIT_ID}
	git-r3_checkout "${FETCH_URI}/${PART}" ${S}/drivers/$PART

	#pal
	PART="llpc"
	COMMIT_ID="dffcaf4565b4153c8cbff64847efbc0f9fb835f9"
	git-r3_fetch "${FETCH_URI}/${PART}" ${COMMIT_ID}
	git-r3_checkout "${FETCH_URI}/${PART}" ${S}/drivers/$PART

	#spvgen
	PART="spvgen"
	COMMIT_ID="f1bc2ba988273c3724afffe72fe9cd933a022ce7"
	git-r3_fetch "${FETCH_URI}/${PART}" ${COMMIT_ID}
	git-r3_checkout "${FETCH_URI}/${PART}" ${S}/drivers/$PART

	#AMDVLK
	PART="AMDVLK"
	COMMIT_ID="887460b07b85a2db434f169e6d02e693cd3d216d"
	git-r3_fetch "${FETCH_URI}/${PART}" ${COMMIT_ID}
	git-r3_checkout "${FETCH_URI}/${PART}" ${S}/drivers/$PART

	#LLVM. At this moment we had to download appropriate source code to build amdvlk.
	PART="llvm-project"
	COMMIT_ID="a62a00e933c3dc76053d7e9aa2efecb82d473d24"
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
	local myconf=()

	cd "${S}/drivers/xgl"
	if use abi_x86_64 && multilib_is_native_abi; then
		myconf+=( -Bbuilds/Release64 )
	else
		myconf+=( -Bbuilds/Release -DCMAKE_C_FLAGS=-m32 -DCMAKE_CXX_FLAGS=-m32 )
	fi

	if use debug; then
		myconf+=( -DCMAKE_BUILD_TYPE=Debug )
	fi
	cmake -H. "${myconf[@]}"

	if use wayland; then
		myconf+=( -DBUILD_WAYLAND_SUPPORT=ON -DBUILD_WSA=On )
	fi
}

multilib_src_compile() {
	ewarn "AMDVLK seems doesn't currently support -O2, -O3 and -Os CFLAFS so fallback it to -O1."
	ewarn "See https://github.com/GPUOpen-Drivers/AMDVLK/issues/56 "
	ewarn "And also there are issues with avx:"
	ewarn "https://github.com/GPUOpen-Drivers/AMDVLK/issues/50"

	replace-flags -O2 -O1
	replace-flags -Os -O1
	filter-flags -O3
	append-flags -mno-avx -mno-avx2 -fstack-protector-strong -fno-plt

	if use abi_x86_64 && multilib_is_native_abi; then
		BUILD_DIR="${S}/drivers/xgl/builds/Release64"
	else
		BUILD_DIR="${S}/drivers/xgl/builds/Release"
	fi

	cd ${BUILD_DIR}
	emake
}

multilib_src_install() {
	if use abi_x86_64 && multilib_is_native_abi; then
		BUILD_DIR="${S}/drivers/xgl/builds/Release64"
		mkdir -p $D/usr/lib64/
		mv "${BUILD_DIR}/icd/amdvlk64.so" $D/usr/lib64/
		insinto /usr/share/vulkan/icd.d
		doins ${S}/drivers/AMDVLK/json/Redhat/amd_icd64.json
	else
		BUILD_DIR="${S}/drivers/xgl/builds/Release"
		mkdir -p $D/usr/lib/
		mv "${BUILD_DIR}/icd/amdvlk32.so" $D/usr/lib/
		insinto /usr/share/vulkan/icd.d
		doins ${S}/drivers/AMDVLK/json/Redhat/amd_icd32.json
	fi
}

multilib_src_install_all(){
	insinto /usr/share/X11/xorg.conf.d/
	doins ${T}/10-amdvlk-dri3.conf
	ewarn "AMDVLK Requires DRI3 so istalled /usr/share/X11/xorg.conf.d/10-amdvlk-dri3.conf"
	ewarn "It's safe to double xorg configuration files if you have already had ones"
}

pkg_postinst() {
	elog "More information about the configuration can be found here:"
	elog " https://github.com/GPUOpen-Drivers/AMDVLK"
	ewarn "Make sure following line is NOT included in the any Xorg configuration section: "
	ewarn "Driver      \"modesetting\""
}
