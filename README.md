<p align="center"><img src="iphone/iLiberated/Assets.xcassets/AppPickerLogo.imageset/AppPickerLogo@3x.png" alt="iLiberated logo" width="345"></p>

**iLiberated** runs classic 32-bit iPhone OS apps and games on modern iPhones and iPads.

It is an independent fork of **iDared 32bit**, which is based on **[touchHLE](https://github.com/touchHLE/touchHLE)**, a high-level emulator for early iPhone OS apps. iLiberated is not affiliated with or endorsed by iDared or touchHLE.
The emulation and iOS host build on work by those projects; their authorship and license notices are preserved.

Project and source: <https://github.com/antonc27/iliberated>

Support and compatibility reports: <https://github.com/antonc27/iliberated/issues>

## What's different in this build

- **iOS host app** which runs as a native app on iPhone and iPad.
- **An interpreter instead of Dynarmic** for CPU emulation. The CPU core is an ARM interpreter derived from [mGBA](https://github.com/mgba-emu/mgba)'s, extended from ARMv4T to ARMv7s, with Thumb-2, VFPv3/VFPv4 and NEON. The only code run by the [emulated CPU](vendor/mgba_arm/) is the app binary and [a handful of libraries](touchHLE_dylibs/).
- **OpenAL via SDL Audio** for the guest-facing `OpenAL.framework` and Audio Toolbox playback, instead of the OpenAL Soft C library.
- **Changes inherited from iDared 32bit** — including work by Alex Martin ([@apexad](https://github.com/apexad)) and other contributors that enables games not supported by upstream touchHLE.

## Based on iDared 32bit

- Upstream project: <https://github.com/iDared32bit-emu/iDared32bit>

## Based on touchHLE

For reference only:
- Original project: <https://github.com/touchHLE/touchHLE>
- touchHLE's website: <https://touchhle.org/>
- touchHLE app compatibility database: <https://appdb.touchhle.org/>

These belong to touchHLE, not iLiberated. **Do not ask touchHLE for support with iLiberated, and do not submit iLiberated app compatibility results to touchHLE's website or its app compatibility database.** Please bring questions, problems and compatibility reports for iLiberated here instead.

The goal of this project is to run games from the early days of iOS:

* Currently: iPhone, iPod touch, and iPad apps for iPhone OS 2.x, iPhone OS 3.x and iOS 4.x.
* Later: iOS 5.x and beyond.
* [Never](https://github.com/touchHLE/touchHLE/issues/181#issuecomment-1777098259): 64-bit iOS.

**This does not mean that all apps for these OS versions work.** The vast majority of iPhone OS 2.x, iPhone OS 3.x and iOS 4.x apps do not currently work in touchHLE or iLiberated, and the ones that do work are generally games (support for other apps isn't a priority: it's more complex and less fun). This improves gradually over time with contributions from various developers. touchHLE's app compatibility database tracks touchHLE only; it does not cover iLiberated. **We don't take requests, so please do not ask us to support your favourite game.**

Because iLiberated uses a different CPU backend, SDL-based audio, iOS-specific changes, and additional maintainer changes that are not in upstream touchHLE, compatibility may differ from touchHLE. Some games that work in touchHLE may not work in iLiberated, and vice versa.

## Platform support

iLiberated primarily targets a native **iOS** app for iPhone and iPad (AArch64). See the [building guide](dev-docs/building.md) to build it yourself.

* Primary targets:
  * iOS 15 and later.
  * iOS Simulator on Apple Silicon and Intel Macs, for development. See the [Simulator build instructions](dev-docs/building.md#ios-simulator).
  * AArch64 macOS, which is used for development. You must build it yourself.
* Inherited from touchHLE, but not verified in this fork: x64 macOS, x64 and AArch64 Linux, x64 Windows and AArch64 Android. You must build these yourself.

iLiberated is a separate project from the iDared App Store app. This fork's GitHub Actions only check formatting and run lint and tests; they don't build releases.

## Important disclaimers

This project is not affiliated with or endorsed by Apple Inc in any way. iPhone, iOS, iPod, iPod touch and iPad are trademarks of Apple Inc in the United States and other countries.

Only use iLiberated to emulate software you have obtained legally.

Not an official iDared 32bit release, and not affiliated with or endorsed by the iDared 32bit project. Please send iLiberated questions, problems and compatibility reports to this repository, not to iDared's support channels.

Not an official touchHLE release — please direct questions or problems regarding iLiberated here, not to the touchHLE project.

Not affiliated with or endorsed by the mGBA project, whose ARM interpreter iLiberated's CPU core is derived from — please direct questions or problems regarding iLiberated here, not to the mGBA project.

## Graphical user interface

iLiberated uses the same built-in app picker on all platforms. If you put your `.ipa` files and `.app` bundles in the `Games` folder, they will show up in the app picker when you run iLiberated. Note that the app binary must not be encrypted to be usable.
To access the `Games` folder, simply tap the “File manager” button in iLiberated.

On iPhone and iPad, the File manager button opens the app's Documents folder in Files. You can return to the picker after using Files or visiting the website. Quick options apply to the next game you launch, and Copyright info shows the bundled license notices.

To configure the options, you can edit the `Options.txt` file. To get a list of options, look in the `OPTIONS_HELP.txt` file.

Any data saved by the app (e.g. **saved games**) are stored in the `Saves` folder.

These are the names on iOS. Older versions used touchHLE's names (`touchHLE_apps`, `touchHLE_options.txt`, `touchHLE_sandbox` and `touchHLE_wallpaper.png`), and iLiberated moves them to the new names automatically. Other platforms still use touchHLE's names.

iLiberated uses the app identifier `org.ac27.iliberated` on iOS and Android, so it installs separately from iDared 32bit and has its own storage. To move from iDared 32bit, copy your games, saves and options into iLiberated's folders using the file manager. The automatic filename migration above only applies to files already inside iLiberated's storage.

## License

iLiberated © 2026 iLiberated project contributors.

iDared 32bit © 2026 iDared 32bit project contributors.

touchHLE © 2023–2026 touchHLE project contributors.

iLiberated is based on iDared 32bit and touchHLE. Its source code, including the modifications made to it here, is licensed under the Mozilla Public License 2.0 (MPL-2.0).

**Distributed binaries are also licensed under the MPL-2.0. They are not licensed under the GNU General Public License (GPL).** Everything compiled into the executable is licensed under the MPL-2.0 or under more permissive terms; none of it is GPL-licensed.

The app carries copies of the libgcc and libstdc++ dynamic libraries from Apple's iPhone OS SDK (`touchHLE_dylibs/`), which apps running inside the emulated device link against. These are separate programs, licensed under the GNU GPL version 2 or later. They run only inside the emulated device, are not linked with iLiberated, and do not change its license. Their license notices, and a written offer for their source code, are included in the app's license information.

Copyright, authorship, and license notices for iDared 32bit, touchHLE, mGBA, and bundled components are preserved in the source and available through the app's license information. See `LICENSE`, `src/licenses.rs`, and the applicable bundled-component directories for details.

### Name, logo and app icon

The iLiberated logo and app icon are original artwork for this fork, distributed under the MPL-2.0. Their editable vector sources are `res/icon.svg` and `res/logo.svg`; see `res/README.md` for regeneration instructions. The app uses:

- `iphone/iLiberated/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (the app icon)
- `res/icon.png` (a copy of the app icon, used by the other platforms)
- `iphone/iLiberated/Assets.xcassets/AppPickerLogo.imageset/AppPickerLogo@3x.png` (the logo)

The iDared 32bit name, logo and app icon are © 2026 Alex Martin, all rights reserved. iLiberated does not include or use that artwork. References to iDared in this repository identify upstream history, attribution or dependencies; they do not imply affiliation. Dependency URLs retain their real upstream locations.

# Thanks

We stand on the shoulders of giants. Thank you to:

* Everyone who has contributed to the project or supported any of its contributors financially.
* The authors of and contributors to the many libraries used by this project: [mGBA](https://github.com/mgba-emu/mgba) (whose ARM interpreter core, modified, is vendored in [vendor/mgba_arm/](vendor/mgba_arm/)), [rust-macho](https://github.com/flier/rust-macho), [SDL](https://libsdl.org/), [rust-sdl2](https://github.com/Rust-SDL2/rust-sdl2), [stb\_image](https://github.com/nothings/stb), Imagination Technologies' [PVRTC decompressor](https://github.com/powervr-graphics/Native_SDK/blob/master/framework/PVRCore/texture/PVRTDecompress.cpp), [hound](https://github.com/ruuda/hound), [Symphonia](https://github.com/pdeljanov/Symphonia), [RustType](https://gitlab.redox-os.org/redox-os/rusttype), [the Liberation fonts](https://github.com/liberationfonts/liberation-fonts), [the Noto CJK fonts](https://github.com/googlefonts/noto-cjk), [rust-plist](https://github.com/ebarnard/rust-plist), [nibarchive](https://github.com/michaelwright235/nibarchive), [quick-xml](https://github.com/tafia/quick-xml), [gl-rs](https://github.com/brendanzab/gl-rs), [cargo-license](https://github.com/onur/cargo-license), [cc-rs](https://github.com/rust-lang/cc-rs), [cmake-rs](https://github.com/rust-lang/cmake-rs), [cargo-ndk](https://github.com/bbqsrc/cargo-ndk), [cargo-ndk-android-gradle](https://github.com/willir/cargo-ndk-android-gradle), [md-5 and sha1](https://github.com/RustCrypto/hashes), [encoding_rs](https://github.com/hsivonen/encoding_rs), [corosensei](https://github.com/Amanieu/corosensei), [uuid](https://github.com/uuid-rs/uuid) and the Rust standard library.
* The [Rust project](https://www.rust-lang.org/) generally.
* The various people out there who've documented the iPhone OS platform, officially or otherwise. Much of this documentation is linked to within this codebase!
* The iOS hacking/jailbreaking community.
* The Free Software Foundation, for making libgcc and libstdc++ copyleft and therefore saving this project from ABI hell.
* Many friends who took an interest in the project and gave suggestions and encouragement.
* Developers of early iPhone OS apps. What treasures you created!
* Apple, and NeXT before them, for creating such fantastic platforms.
