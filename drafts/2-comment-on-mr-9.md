# Comment — merge request !9 "Add KDE theming support"

- **Where:** <https://www.opencode.net/trialuser/qt6ct/-/merge_requests/9> (author: Ilya Fedin,
  branch `kde` of <https://www.opencode.net/ilya-fedin/qt6ct>, head `3e84eaa4238d`)
- **Patch:** `patches/qt6ct-kde-branch-reparse-color-scheme.patch`
- **Status:** not sent.
- `<MR-LINK>` below is the link of the watcher merge request, known only once that one is open.

## Text

A KDE color scheme that gets new content at the same path is never reloaded by a running
application, even when qt6ct does reload its settings.

**To reproduce** (also with qt6ct-kde 0.11-8 from the AUR; Qt 6.12.0, KColorScheme 6.30.0,
Breeze 6.7.5, Dolphin 26.08.1)

1. `custom_palette=true`, `color_scheme_path=/path/to/scheme.colors`.
2. Start Dolphin with `QT_QPA_PLATFORMTHEME=qt6ct`.
3. Replace the content of `scheme.colors` with another scheme (dark → light).
4. Save `qt6ct.conf` again. `qt6ct.debug` logs `updating settings..`, and view, panels and toolbar
   keep the old colors.

**Cause**

- `Qt6CT::loadColorScheme()` uses `KSharedConfig::openConfig(filePath)`, which returns the instance
  already parsed for that path. `KColorScheme` reads the same instance through
  `KDE_COLOR_SCHEME_PATH`.
- Breeze's `ToolsAreaManager` holds a second instance of the file, opened with
  `KConfig::NoGlobals`, and keeps it while the path is unchanged.

**Proposed change** (applies to `kde` at `3e84eaa`)

```diff
     if(isKColorScheme(filePath))
-        return KColorScheme::createApplicationPalette(KSharedConfig::openConfig(filePath));
+    {
+        //KSharedConfig instances are shared and cached, so a file that got new content has to be
+        //parsed again. This instance is also the one KColorScheme reads.
+        KSharedConfigPtr config = KSharedConfig::openConfig(filePath);
+        config->reparseConfiguration();
+        //Breeze keeps its own instance of the file for the tools area, opened with NoGlobals
+        KSharedConfig::openConfig(filePath, KConfig::NoGlobals)->reparseConfiguration();
+        return KColorScheme::createApplicationPalette(config);
+    }
```

With it, an unmodified Dolphin follows dark → light → dark and a regenerated scheme at the same
path: view, places panel and toolbar. With the first `reparseConfiguration()` alone, view and panel
follow and the toolbar stays on its start colors — the second line exists only for Breeze, and I
would understand preferring to fix that on the Breeze side instead.

Related: `<MR-LINK>` makes qt6ct watch the color scheme file itself, so step 4 is no longer needed.
It adds `m_schemePath` to the platform theme, as this branch does, so whichever lands second needs a
small rebase; I can do that, or open this as a merge request against `kde` if that is easier.
