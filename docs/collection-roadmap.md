# Collection support for the first release

The current catalog includes C&C/Tiberian Dawn and Red Alert via OpenRA,
Generals and Zero Hour via GeneralsX, plus experimental original Red Alert 2,
Yuri’s Revenge and Tiberian Sun/Firestorm through Wine + cnc-ddraw. The user has
reported working Red Alert 2 gameplay; that is not a blanket validation of every
Wine game, desktop or mod. OpenRA gameplay differs from the original clients.

C&C 3/Tiberium Wars, Kane’s Wrath, Red Alert 3/Uprising, Renegade and Tiberian
Twilight are deferred from this release. They require an additional 3D graphics
path and game-specific startup/dependency validation. Adding their Steam IDs to
our 2D profile list would not provide that graphics support.

The older [Gcenx DXVK-macOS releases](https://github.com/Gcenx/DXVK-macOS/releases)
explicitly exclude Direct3D 9. A newer [DXVK-MacOS fork](https://github.com/metalsharp/DXVK-MacOS)
includes D3D9 work but documents a Wine portability patch, runtime rebuilding and
additional deployment requirements. That is a possible future investigation,
not a verified drop-in replacement for this launcher’s pinned Wine runtime.
Linux has other Wine/Proton graphics options, but adding only a Steam ID would
still leave a new platform-specific setup and test path.

The first release keeps the current catalog rather than displaying unplayable
entries or introducing another unvalidated runtime source. Later 3D support must
use legally owned Steam data, preserve existing profiles and saves, pin the new
runtime, pass the same security gates, and receive explicit gameplay validation.
