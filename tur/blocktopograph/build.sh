TERMUX_PKG_HOMEPAGE=https://github.com/NguyenDuck/blocktopograph
TERMUX_PKG_DESCRIPTION="A world editor for Minecraft Bedrock written in rust."
TERMUX_PKG_LICENSE="GPL-3.0-only" # and CC BY-NC-SA 4.0
TERMUX_PKG_MAINTAINER="@termux-user-repository"
_COMMIT=20bec959428d39f1f124a220b4c4aae3974fcbae
_COMMIT_DATE=20250306
TERMUX_PKG_VERSION="0.0.1-p${_COMMIT_DATE}"
TERMUX_PKG_SRCURL=git+https://github.com/NguyenDuck/blocktopograph.git
TERMUX_PKG_GIT_BRANCH=rewrite
TERMUX_PKG_SHA256=23ff84902ad17743e5d297e2efecbad0f33c5eb322452d9338a7475dbd5dbf45
TERMUX_PKG_DEPENDS="libxi, libxcursor, libxkbcommon, libxrandr"
TERMUX_PKG_BUILD_IN_SRC=true


__fetch_dep_source_for_force_patching_unmangled_cargo_toml() {
	local _author="$1"
	local _name="$2"
	local _tag="$3"
	local _url="https://github.com/$_author/$_name/archive/refs/tags/$_tag.tar.gz"
	local _path="$TERMUX_PKG_CACHEDIR/$_name-$_tag.tar.gz"
	termux_download "$_url" "$_path" SKIP_CHECKSUM
	tar xf "$_path" -C "$TERMUX_PKG_SRCDIR"
	mv "$_name-"* "$_name-source"
}

__fetch_dep_source_using_git() {
	local _author="$1"
	local _name="$2"
	local _commit="$3"
	local _url="https://github.com/$_author/$_name.git"
	local _path="$TERMUX_PKG_SRCDIR/$_name-source"
	git clone "$_url" "$_path"
	pushd $_path
	git checkout $_commit
	popd
}

termux_step_post_get_source() {
	git fetch --unshallow
	git checkout $_COMMIT

	local pdate="p$(git log -1 --format=%cs | sed 's/-//g')"
	if [[ "$TERMUX_PKG_VERSION" != *"${pdate}" ]]; then
		echo -n "ERROR: The version string \"$TERMUX_PKG_VERSION\" is"
		echo -n " different from what is expected to be; should end"
		echo " with \"${pdate}\"."
		return 1
	fi

	local s=$(find . -type f ! -path '*/.git/*' -print0 | xargs -0 sha256sum | LC_ALL=C sort | sha256sum)
	if [[ "${s}" != "${TERMUX_PKG_SHA256}  "* ]]; then
		termux_error_exit "Checksum mismatch for source files."
	fi
}

termux_step_pre_configure() {
	termux_setup_rust

	: "${CARGO_HOME:=$HOME/.cargo}"
	export CARGO_HOME

	__fetch_dep_source_for_force_patching_unmangled_cargo_toml bevyengine bevy v0.15.1
	# __fetch_dep_source_for_force_patching_unmangled_cargo_toml JonahPlusPlus bevy_atmosphere 0.12.2
	__fetch_dep_source_for_force_patching_unmangled_cargo_toml rust-windowing winit v0.30.8
	__fetch_dep_source_for_force_patching_unmangled_cargo_toml rust-windowing raw-window-handle v0.6.2
	__fetch_dep_source_for_force_patching_unmangled_cargo_toml AccessKit accesskit accesskit-v0.17.1
	__fetch_dep_source_for_force_patching_unmangled_cargo_toml psychon x11rb v0.13.1
	__fetch_dep_source_for_force_patching_unmangled_cargo_toml rust-windowing xkbcommon-dl v0.4.2
	# __fetch_dep_source_using_git RustAudio cpal 33b8919516e950ce770f7b63e144ac54d6556ea0
	__fetch_dep_source_for_force_patching_unmangled_cargo_toml gfx-rs wgpu v23.0.0


	patch="$TERMUX_PKG_BUILDER_DIR/patch-root-Cargo.toml.diff"
	patch -p1 -d "$TERMUX_PKG_SRCDIR" < "$patch"

	patch="$TERMUX_PKG_BUILDER_DIR/disable-bevy_audio.diff"
	patch -p1 -d "$TERMUX_PKG_SRCDIR/bevy-source" < "$patch"
	patch="$TERMUX_PKG_BUILDER_DIR/bevy-drop-wgpu-to-23.0.0.diff"
	patch -p1 -d "$TERMUX_PKG_SRCDIR/bevy-source" < "$patch"

	# patch="$TERMUX_PKG_BUILDER_DIR/wgpu-23.0.1-custom.diff"
	# patch -p1 -d "$TERMUX_PKG_SRCDIR/z-wgpu-source-v23.0.1" < "$patch"

	# force-disable all SurfaceFlinger-intended (ANativeWindow) code in the "android" target of Bevy Engine
	# and force-enable all Xorg-intended (X11) code in the "android" target of Bevy Engine
	# TODO: micromanage the patching of rustix to enable specifically the shm by itself (supported by libandroid-shm)
	# like alacritty in termux-packages
	find "$TERMUX_PKG_SRCDIR"/{bevy*,wgpu*,winit*,raw-window-handle*,accesskit*} -type f | \
		xargs -n 1 sed -i \
		-e 's|target_os = "android"|target_os = "disabling_this_because_it_is_for_building_an_apk"|g' \
		-e 's|target_os = "linux"|target_os = "android"|g' || :

	# patch X11 dependency crates for X11-on-Android paths
	find "$TERMUX_PKG_SRCDIR"/{x11rb*,xkbcommon*} -type f | \
		xargs -n 1 sed -i \
		-e "s|/tmp/.X11-unix|$TERMUX_PREFIX/tmp/.X11-unix|g" \
		-e "s|libxkbcommon.so.0|libxkbcommon.so|g" \
		-e "s|libxkbcommon-x11.so.0|libxkbcommon-x11.so|g" \
		-e "s|libxcb.so.1|libxcb.so|g" \
		-e '/unused_qualifications/d' || :

	# rm -rf "$CARGO_HOME"/registry/src/
	
	cargo update

}

# termux_step_post_massage() {
# 	rm -rf "$CARGO_HOME"/registry/src/
# }
