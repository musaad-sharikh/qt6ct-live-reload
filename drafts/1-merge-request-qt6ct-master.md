# Merge request — official qt6ct

- **Project:** <https://www.opencode.net/trialuser/qt6ct> (owner: Ilya Kotov)
- **Target branch:** `master` at `00823e41aa60`
- **Source branch (in a fork):** `fix/reload-color-scheme-file`
- **Commit:** `fix: reload the color scheme file when it changes`, one commit on top of `master`
- **Patch:** `patches/qt6ct-master-watch-scheme-file.patch` (identical to the commit)
- **Status:** not sent.

## Commit message

```
fix: reload the color scheme file when it changes

Only the configuration directory was watched, so applications that are
already running kept their palette when the custom color scheme file was
rewritten and qt6ct.conf was left untouched.

Watch the color scheme file as well. A file that is replaced or removed
drops out of QFileSystemWatcher, so the nearest existing directory above
it is watched too, only to add the file back; other changes in that
directory are ignored.
```

## Title

fix: reload the color scheme file when it changes

## Description

Running applications keep their old palette when the custom color scheme file is rewritten and
`qt6ct.conf` is left untouched. Tools that generate a palette (wallpaper-based themers, light/dark
switchers) rewrite the scheme file itself, so nothing reaches applications that are already open.

**To reproduce**

1. Enable a custom palette and point `color_scheme_path` at `~/.config/qt6ct/colors/test.conf`.
2. Start any Qt application with `QT_QPA_PLATFORMTHEME=qt6ct`.
3. Overwrite `test.conf` with different colors, without touching `qt6ct.conf`.

The application keeps the old palette until it is restarted or `qt6ct.conf` is saved again.

**Cause**

`createFSWatcher()` watches only `Qt6CT::configPath()`. The watch is not recursive, and a file
rewritten in place produces no directory event anyway.

**Change**

- watch the resolved color scheme file and feed `fileChanged` into the existing 3 s timer;
- watch the nearest existing directory above it only to put the file back after it was replaced,
  removed or created late, including when its directory does not exist yet; unrelated files in that
  directory do not trigger a reload;
- re-evaluate both watches after every reload, so a changed `color_scheme_path` is followed and the
  old file is dropped.

**Testing** (Qt 6.12.0, plugin loaded from a private `QT_PLUGIN_PATH`, offscreen)

| Case | master | with this change |
|---|---|---|
| file rewritten in place | no reload | reloads |
| file replaced by rename | no reload | reloads |
| file deleted and recreated | no reload | reloads |
| 40 unrelated files created and removed beside it | — | no reload |
| 10 writes within one second | — | one reload |
| `color_scheme_path` changed to a file that does not exist yet, file created later | — | reloads when it appears |
| the same with its directories missing too | — | reloads when it appears |
| file unreadable (`addPath()` fails), then replaced by a readable one | — | reloads after the replacement |
| its four parent directories created and removed about 5000 times in 10 s | — | no reload, stays responsive, then follows the file once it exists |

The number of inotify watches stays at three while the file exists (config directory, scheme file,
its directory) and at two while it is missing.
