#!/bin/bash
# usage: dol.sh <scratch> <name> <stock|patched>   -- real /usr/bin/dolphin, offscreen, private bus, scratch HOME
. "$(dirname "$0")/isolate.sh"
S="$1"; N="$2"; BUILD="$3"; Q="$S/qtct"; R="$S/probe/dol/$N"; rm -rf "$R"; H="$R/home"
mkdir -p "$H/.config/qt6ct" "$H/.local/share/color-schemes" "$H/files/sub" "$R/out"; touch "$H/files/a.txt" "$H/files/b.txt"; LOG="$R/log.txt"
cat > "$R/t.toml" <<T
[config]
[templates.k]
input_path = "$HOME/.config/noctalia/templates/kcolorscheme.colors"
output_path = "$H/.local/share/color-schemes/noctalia.colors"
post_action = "kde-color-scheme"
T
sed "s|^color_scheme_path=.*|color_scheme_path=$H/.local/share/color-schemes/noctalia.colors|" "$HOME/.config/qt6ct/qt6ct.conf" > "$H/.config/qt6ct/qt6ct.conf"
PAL="$HOME/.config/noctalia/palettes/noctalia-local.json"
E=(env -i PATH="$PATH" HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" XDG_CACHE_HOME="$H/.cache" XDG_STATE_HOME="$H/.local/state" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" LANG=C.UTF-8)
render(){ local P="$PAL" M="$1"; if [ "$1" = regen ]; then P="$Q/palette-regen.json"; M=dark; fi; "${E[@]}" noctalia theme --theme-json "$P" --default-mode "$M" -c "$R/t.toml" >/dev/null 2>&1
          dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:0 int32:0; if [ -n "$RESAVE" ]; then cp "$H/.config/qt6ct/qt6ct.conf" "$H/.config/q.tmp" && mv "$H/.config/q.tmp" "$H/.config/qt6ct/qt6ct.conf"; fi; }
render ${INIT:-dark}
X=(QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=qt6ct QT_FORCE_STDERR_LOGGING=1 QT_LOGGING_RULES=qt6ct.debug=true LD_PRELOAD="$S/probe/dol/inject.so" PROBE_OUT="$R/out")
[ "$BUILD" = patched ] && X+=(QT_PLUGIN_PATH="$Q/${PLUG:-plug}" LD_LIBRARY_PATH="$Q/${LIB:-lib}")
"${E[@]}" "${X[@]}" /usr/bin/dolphin --new-window "$H/files" >> "$LOG" 2>&1 &
PID=$!
ev(){ echo "EVT $*" >> "$LOG"; }
sleep 6; ev "dolphin $("${E[@]}" QT_QPA_PLATFORM=offscreen /usr/bin/dolphin --version) pid alive: $(kill -0 $PID 2>/dev/null && echo yes || echo NO); theme plugin: $(grep -oE '/[^ ]*platformthemes/libqt6ct.so' /proc/$PID/maps | sort -u)"
for m in ${SEQ:-light dark regen dark light}; do ev "switch -> $m"; render $m; sleep 6; done
ev "alive at end: $(kill -0 $PID 2>/dev/null && echo yes || echo NO)"; kill $PID 2>/dev/null; sleep 1
echo "##### $N  real dolphin, $BUILD plugin"; grep -E '^(PAL|EVT)' "$LOG" | sed "s#$S/##" | cut -c1-150; ls "$R/out"
