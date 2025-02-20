TERMUX_PKG_HOMEPAGE=https://www.supertux.org
TERMUX_PKG_DESCRIPTION="SuperTux is a jump'n'run game with strong inspiration from the Super Mario Bros. games for the various Nintendo platforms."
TERMUX_PKG_LICENSE="GPL-3.0"
TERMUX_PKG_MAINTAINER="@termux-user-repository"
# current release (0.6.3) of supertux ignores -DUSE_SYSTEM_SDL2_TTF=ON and errors with
# FAILED: SDL_ttf-prefix/src/SDL_ttf-stamp/SDL_ttf-configure
# /home/builder/.termux-build/supertux/src/SDL_ttf-prefix/src/SDL_ttf-stamp/SDL_ttf-configure
# the development branch is unaffected by that problem (after applying fix-sdl2-ttf-detection.patch)
_COMMIT=5b6898d64f1718d29d0f1bea48a8a7e2afd06b51
_COMMIT_DATE=20250216
TERMUX_PKG_VERSION="0.6.3-p${_COMMIT_DATE}"
TERMUX_PKG_SRCURL=git+https://github.com/SuperTux/supertux.git
TERMUX_PKG_SHA256=b124693439494d068e9c6c1775f6b8e213edc01d5fce670cbb627b183e081cc3
TERMUX_PKG_GIT_BRANCH=master
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_FORCE_CMAKE=true
TERMUX_PKG_BUILD_DEPENDS="boost-headers"
TERMUX_PKG_DEPENDS="boost, glm, sdl2, sdl2-image, sdl2-ttf, fmt, glew, openal-soft, libphysfs, libandroid-execinfo, supertux-data"

TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
-DIS_SUPERTUX_RELEASE=true
-DINSTALL_SUBDIR_BIN=bin
-DUSE_SYSTEM_SDL2_TTF=ON
"

TERMUX_PKG_RM_AFTER_INSTALL="
lib/libsimplesquirrel_static.a
lib/libsqstdlib_static.a
lib/libsquirrel_static.a
"

termux_step_get_source() {
	local TMP_CHECKOUT=$TERMUX_PKG_CACHEDIR/tmp-checkout
	local TMP_CHECKOUT_VERSION=$TERMUX_PKG_CACHEDIR/tmp-checkout-version

	if [ ! -f $TMP_CHECKOUT_VERSION ] || [ "$(cat $TMP_CHECKOUT_VERSION)" != "$TERMUX_PKG_VERSION" ]; then
		rm -rf $TMP_CHECKOUT
		git clone --depth 1 \
			--branch $TERMUX_PKG_GIT_BRANCH \
			${TERMUX_PKG_SRCURL:4} \
			$TMP_CHECKOUT

		pushd $TMP_CHECKOUT
		git fetch --unshallow
		git checkout $_COMMIT

		# (do not attempt to fetch all submodules,
		# only specific ones that cannot be provided by system)
		# fatal: remote error: upload-pack: not our ref 131bf6815d3fe4cdccb79effa8ca4671e79fd0bb
		git submodule update --init --recursive external/simplesquirrel/
		git submodule update --init --recursive external/tinygettext/
		git submodule update --init --recursive external/sexp-cpp/
		popd

		echo "$TERMUX_PKG_VERSION" > $TMP_CHECKOUT_VERSION
	fi

	rm -rf $TERMUX_PKG_SRCDIR
	cp -Rf $TMP_CHECKOUT $TERMUX_PKG_SRCDIR
}

termux_step_post_get_source() {
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
	# on careful inspection, it can be calculated that all instances of __ANDROID__
	# in the source code of supertux are intended for use with SurfaceFlinger (ANativeWindow)
	# (building an APK), and are not suitable for X11,
	# so it is safe to copy the exact patching method used by x11/sdl2.
	find "$TERMUX_PKG_SRCDIR" -type f | \
		xargs -n 1 sed -i \
		-e 's/\([^A-Za-z0-9_]__ANDROID\)\(__[^A-Za-z0-9_]\)/\1_NO_TERMUX\2/g' \
		-e 's/\([^A-Za-z0-9_]__ANDROID\)__$/\1_NO_TERMUX__/g'

	export LDFLAGS+=" -landroid-execinfo"

	# successful application-side workaround of
	# https://github.com/kcat/openal-soft/issues/1111
	# https://github.com/termux/termux-packages/issues/23148
	# future of termux-packages openal-soft package unknown:
	# if https://github.com/termux/termux-packages/pull/23149 is merged,
	# this would not be required after merging,
	# but if it is not and https://github.com/termux/termux-packages/pull/23185 is merged instead,
	# then this would remain required.
	export LDFLAGS+=" -Wl,--no-as-needed,-lOpenSLES,--as-needed"
}

