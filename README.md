# qt6ct: reload a rewritten colour scheme in running applications

Two small patches that make Qt and KDE applications which are **already open** follow a colour
scheme file that is rewritten on disk, a local Arch package that carries them, and the tests behind
them.

The case that prompted it: [Noctalia](https://github.com/noctalia-dev/noctalia) rewrites
`~/.local/share/color-schemes/noctalia.colors` in place at every light/dark switch and every
wallpaper change, and `qt6ct.conf` points `color_scheme_path` at that file. Dolphin, which keeps a
`dolphin --daemon` alive for the whole session, kept the colours it had started with.

## Cause

Two independent defects. Either one alone keeps a running application on its old colours.

1. **Nothing watches the scheme file.** `Qt6CTPlatformTheme::createFSWatcher()` in
   [qt6ct](https://www.opencode.net/trialuser/qt6ct) watches only the configuration directory
   `~/.config/qt6ct`, non-recursively. A scheme file anywhere else, including qt6ct's own
   `colors/` subdirectory, changes without a reload being scheduled.
2. **The KDE scheme is read through cached `KSharedConfig` instances.** The KDE theming patch
   shipped by the AUR package [`qt6ct-kde`](https://aur.archlinux.org/packages/qt6ct-kde) (upstream
   merge request [!9](https://www.opencode.net/trialuser/qt6ct/-/merge_requests/9)) loads a
   `.colors` file with `KSharedConfig::openConfig(filePath)`, which returns the instance already
   parsed for that path. `KColorScheme` reads the same instance, and Breeze's `ToolsAreaManager`
   keeps a second one opened with `KConfig::NoGlobals`. A reload therefore yields the old palette,
   and after reparsing only the first instance the toolbar alone stays stale.

## Patches

| File | Applies to | What it does |
|---|---|---|
| `patches/qt6ct-master-watch-scheme-file.patch` | qt6ct `master` at `00823e41aa60` (= tag 0.11) | watches the scheme file, and the nearest existing directory above it to put the file back after it was replaced, removed or created late |
| `patches/qt6ct-kde-branch-reparse-color-scheme.patch` | branch `kde` of `ilya-fedin/qt6ct` at `3e84eaa4238d` (merge request !9) | reparses both shared `KSharedConfig` instances of the scheme file |
| `patches/qt6ct-kde-aur-0.11-8-live-reload.patch` | qt6ct 0.11 with the AUR patch of `qt6ct-kde` 0.11-8 applied | both changes together; this is what the package below builds |

The watcher keeps qt6ct's own 3 s debounce, so colours follow a write by about three seconds.
Changes to unrelated files in the watched directory do not trigger a reload.

Neither change has been submitted upstream yet; `drafts/` holds the merge request text for qt6ct
and the comment for merge request !9.

## Local package

`pkg/qt6ct-kde/PKGBUILD` builds `qt6ct-kde 0.11-8.1`: qt6ct 0.11, the KDE theming patch of the AUR
package `qt6ct-kde` 0.11-8, and `qt6ct-live-reload.patch`. It keeps the AUR package's name, so it
replaces that build in place and nothing else has to change.

This recipe was built from scratch in an empty directory (`makepkg -d`, with `cmake` and
`qt6-tools` taken from their package files): the package has the same 19 files and the same library
dependencies as the installed build, and its libraries pass the watcher cases and the real-Dolphin
run in `results/recipe/`.

The KDE theming patch is not part of this repository. `makepkg` downloads it from the AUR at a
pinned commit (`8c1003e13b7e`) and checks its SHA-256, so a build needs the AUR to be reachable.

Build, without installing:

```sh
cd pkg/qt6ct-kde
makepkg -sr        # -s installs cmake and qt6-tools for the build, -r removes them again
```

Install, then restart the Qt applications that should pick it up (a running process keeps the
plugin it loaded):

```sh
sudo pacman -U qt6ct-kde-0.11-8.1-x86_64.pkg.tar.zst
```

Roll back to the stock build by installing its package file again, from wherever it was kept
(`paru` leaves it in `~/.cache/paru/clone/qt6ct-kde/`), or by reinstalling from the AUR:

```sh
sudo pacman -U qt6ct-kde-0.11-8-x86_64.pkg.tar.zst
```

Tell a patched plugin from a stock one (1 = patched, 0 = stock; the build is stripped, so function
names are not visible):

```sh
nm -D /usr/lib/qt6/plugins/platformthemes/libqt6ct.so | grep -c QFileSystemWatcher11fileChanged
```

### What undoes it

- **A new AUR release.** `0.11-8.1` sorts above `0.11-8` and below `0.11-9`. Once the AUR ships
  `0.11-9` or later, the next AUR upgrade replaces this package with the unpatched build, without
  any notice, unless upstream has taken the fix by then.
- **A Qt minor upgrade** (for example 6.12 to 6.13). Qt refuses a platform theme plugin built for
  another minor version (`Ignoring QPA plugin due to mismatching Qt versions`), patched or not, and
  every Qt application falls back to the default light palette until the package is rebuilt.
  `results/isolated/stock-6.11-build-rejected-by-qt-6.12.log` shows it happening to the stock
  build.

## Evidence

Versions: qt6ct 0.11, qt6ct-kde 0.11-8 (AUR), Qt 6.12.0, KColorScheme and KConfig 6.30.0,
Breeze 6.7.5, Dolphin 26.08.1 and 26.08.2, Noctalia 5.2.1, on CachyOS with niri. Tested 2026-10-08.

### Isolated (`results/isolated/`, `results/package/`)

Every run used a scratch `HOME`, a private D-Bus session and `QT_QPA_PLATFORM=offscreen`; the
plugin under test was loaded through `QT_PLUGIN_PATH` and `LD_LIBRARY_PATH` and confirmed from
`/proc/<pid>/maps`. `results/package/` repeats the suite on the libraries unpacked from the built
package itself.

| Case | Stock | Patched |
|---|---|---|
| scheme rewritten in place, dark → light → dark | no reload | follows |
| palette regenerated inside the same mode | no reload | follows |
| the same with `qt6ct.conf` re-saved after each change (KDE scheme) | reloads, palette unchanged | — |
| file replaced by rename; deleted and recreated | no reload | follows |
| 10 writes within one second | — | one reload |
| 40 unrelated files created and removed beside it | — | no reload |
| `color_scheme_path` changed to another file | — | follows the new file, drops the old one |
| scheme file, or its directories, missing at first and created later | — | follows once it exists |
| unreadable file (`addPath()` fails), then replaced by a readable one | — | follows after the replacement |
| four parent directories created and removed about 5000 times in 10 s | — | stays responsive, no reload, then follows |
| 12 consecutive changes | — | 12 reloads; three inotify watches after every step |
| native qt6ct `.conf` palette; a Qt program without KDE libraries | no reload | follows |
| unmodified Dolphin: file view, places panel, toolbar | one palette for the whole run | all three follow |

Log names: `K*` stock KDE scheme, `U*` official qt6ct with the native format, `Y*`/`Z*`/`M*`/`F*`
the watcher cases, `P*` Noctalia's own renderer doing the switching, `D*` the real Dolphin binary.
In the logs `<scratch>` stands for the scratch directory of the run and `~` for the home directory;
where a log line had already cut a path short, it reads `<scratch>/…`.

### Live (`results/live/`)

`qt6ct-kde 0.11-8.1` installed, one Dolphin window left open and never restarted. Each row is a
`grim` capture of that window's rectangle only, sampled in 9×9 patches away from icons and text and
compared with the scheme file as it was after the change.

| Change | File view | Toolbar | Scheme file |
|---|---|---|---|
| wallpaper changed, dark mode | `#181e25` | `#181e25` (window inactive) | View `#181e25`, Header inactive `#181e25` |
| wallpaper changed again | `#291416` | `#371b1d` | View `#291416`, Header `#371b1d` |
| dark → light | `#fcd3cf` | `#f4a39a` | View `#fcd3cf`, Header `#f4a39a` |
| light → dark | `#072136` | `#092c49` | View `#072136`, Header `#092c49` |

Both Dolphin processes kept exactly three watches (`~/.config/qt6ct`,
`~/.local/share/color-schemes`, `noctalia.colors`), `qt6ct.conf` was never written, and the scheme
file kept one inode throughout, so every change was an in-place rewrite. The toolbar follows the
window's focus state: `[Colors:Header]` when active, `[Colors:Header][Inactive]` when not.

## Running the tests again

The harnesses in `probes/` are the ones that produced the results. They are not a portable test
suite: each takes a scratch root as its first argument and expects the layout the runs used.

Requirements:

- Qt 6 and KDE Frameworks 6 with headers: Qt Core/Gui/Widgets, KColorScheme, KConfig,
  KConfigWidgets; `g++`; the `qml` tool of Qt Declarative (`/usr/lib/qt6/bin/qml`).
- `dbus-run-session`, ImageMagick (`magick`), Python 3; for the live measurement also Pillow, NumPy,
  `grim` and niri.
- `cmake` and `qt6-tools` to build qt6ct; `probes/manual_plugin_build.sh` rebuilds only the plugin
  inside an existing build directory when they are not installed.
- For `scen.sh` and `dol.sh`: Noctalia (`noctalia theme -c`), a KColorScheme template at
  `~/.config/noctalia/templates/kcolorscheme.colors` and a palette at
  `~/.config/noctalia/palettes/noctalia-local.json`. All harnesses also read
  `~/.config/qt6ct/qt6ct.conf` as the base configuration and only change `color_scheme_path` in
  their scratch copy.

Layout under the scratch root: `qtct/plug/{platformthemes,styles}` and `qtct/lib` hold the plugin,
the proxy style and `libqt6ct-common.so*` of the build under test (`PLUG` and `LIB` select another
pair); `probe/kp/kp` is the compiled `kp.cpp`; `probe/dol/inject.so` the compiled `inject.cpp`;
`probe/dyn/src/{dark,light}.colors` and `probe/dyn/watch.qml` the samples from `probes/`.

```sh
INC="-I/usr/include/qt6 -I/usr/include/qt6/QtCore -I/usr/include/qt6/QtGui -I/usr/include/qt6/QtWidgets \
     -I/usr/include/KF6/KColorScheme -I/usr/include/KF6/KConfigCore -I/usr/include/KF6/KConfigGui \
     -I/usr/include/KF6/KConfig -I/usr/include/KF6/KConfigWidgets"
g++ -std=c++20 -fPIC -O1 kp.cpp -o kp $INC \
    -lQt6Core -lQt6Gui -lQt6Widgets -lKF6ColorScheme -lKF6ConfigCore -lKF6ConfigGui -lKF6ConfigWidgets
g++ -std=c++20 -fPIC -shared -O1 inject.cpp -o inject.so $INC \
    -lQt6Core -lQt6Gui -lQt6Widgets -lKF6ColorScheme
dbus-run-session -- ./extra2.sh <scratch> Y4 kpk stress
```

`kp.cpp` is a QApplication that calls `KStyleManager::initStyle()` and, with `--kcsm`,
`KColorSchemeManager::instance()`, as Dolphin does, and prints the palette and a `KColorScheme` on
every change. `inject.cpp` gives the same report from inside an unmodified program through
`LD_PRELOAD` and saves a picture of its main window. `apply_watch.py` and `apply_reparse.py` are the
edits the patches were generated from. `results/live/measure.sh` holds the window id and position
of the session it ran in.

A capture must not be taken during a workspace switch: niri reports the workspace as active while
it is still sliding, and the rectangle then holds part of another window. `measure.sh` takes two
captures 0.8 s apart and discards both when the toolbar strip differs.

## Limits

- Not tested: Fedora's `qt6ct` build, more than one monitor, Flatpak applications.
- A scheme file that is deleted and stays away makes the application fall back to the default
  palette until it reappears; that is qt6ct's existing behaviour for a missing file.
- The second reparse names `KConfig::NoGlobals` because that is how Breeze opens the file. A style
  that caches a different variant would need the same treatment.
- The directory watch settles in at most five rounds; a directory tree that keeps changing is picked
  up at its next change instead.

## Licences and credits

- Everything written for this repository — the probes, harnesses, scripts, documentation and the
  changes the patches make — is under the BSD 2-Clause licence in `LICENSE`,
  Copyright (c) 2026 Musaad Muhammad.
- The patches in `patches/` and `pkg/qt6ct-kde/qt6ct-live-reload.patch` modify
  [qt6ct](https://www.opencode.net/trialuser/qt6ct), Copyright (c) 2020-2025 Ilya Kotov, BSD
  2-Clause, and their context lines are qt6ct's code; its licence is reproduced in
  `LICENSES/BSD-2-Clause-qt6ct.txt`. Two of them apply on top of the KDE theming work by Ilya Fedin
  (merge request !9, shipped by the AUR package `qt6ct-kde`) and quote a few of its lines as
  context. That patch carries no licence statement of its own and is not redistributed here.
- `pkg/qt6ct-kde/PKGBUILD` is derived from the Arch Linux packaging of `qt6ct`
  (<https://gitlab.archlinux.org/archlinux/packaging/packages/qt6ct>), Copyright Arch Linux
  Contributors, 0BSD: `LICENSES/0BSD-arch-packaging.txt`.
- `probes/dark.colors` is a rendering of Noctalia's KColorScheme template, Copyright (c) 2026
  noctalia-dev, MIT: `LICENSES/MIT-noctalia.txt`. `probes/light.colors` is the same file with the
  view, window and text colours exchanged for light ones, made for these tests; it is not a
  palette Noctalia produced.
