#!/bin/bash
# usage: scen.sh <probe-root> <name> <kde|native> <poke|nopoke> [--kcsm]
. "$(dirname "$0")/isolate.sh"
S="$1"; N="$2"; FMT="$3"; POKE="$4"; KCSM="$5"; BUILD="$6"; Q="$S/../qtct"
R="$S/kp/$N"; rm -rf "$R"; mkdir -p "$R/home/.config/qt6ct/colors" "$R/home/.local/share/color-schemes"
H="$R/home"; LOG="$R/log.txt"
if [ "$FMT" = kde ]; then TPL="$HOME/.config/noctalia/templates/kcolorscheme.colors"; OUT="$H/.local/share/color-schemes/noctalia.colors"; fi
cat > "$R/t.toml" <<T
[config]
[templates.k]
input_path = "$HOME/.config/noctalia/templates/kcolorscheme.colors"
output_path = "$H/.local/share/color-schemes/noctalia.colors"
post_action = "kde-color-scheme"
[templates.q]
input_path = "/usr/share/noctalia/assets/templates/qt/qtct.conf"
output_path = "$H/.config/qt6ct/colors/noctalia.conf"
T
[ "$FMT" = kde ] && CSP="$H/.local/share/color-schemes/noctalia.colors" || CSP="$H/.config/qt6ct/colors/noctalia.conf"
sed "s|^color_scheme_path=.*|color_scheme_path=$CSP|" "$HOME/.config/qt6ct/qt6ct.conf" > "$H/.config/qt6ct/qt6ct.conf"
PAL="$HOME/.config/noctalia/palettes/noctalia-local.json"; REALHOME="$HOME"
E=(env -i PATH="$PATH" HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" XDG_CACHE_HOME="$H/.cache" XDG_STATE_HOME="$H/.local/state" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS")
ev(){ echo "$(date +%H:%M:%S.%1N) EVT $*" >> "$LOG"; }
render(){ local P="$PAL" M="$1"; if [ "$1" = regen ]; then P="$Q/palette-regen.json"; M=dark; fi; "${E[@]}" noctalia theme --theme-json "$P" --default-mode "$M" -c "$R/t.toml" >/dev/null 2>&1
          dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:0 int32:0
          C="$H/.config/qt6ct/qt6ct.conf"; D="$H/.local/share/color-schemes"
          setp(){ sed "s|^color_scheme_path=.*|color_scheme_path=$1|" "$C" > "$H/.config/q.tmp" && mv "$H/.config/q.tmp" "$C"; }
          case "$POKE" in
            poke) cp "$C" "$H/.config/q.tmp" && mv "$H/.config/q.tmp" "$C";;
            flip) cp "$D/noctalia.colors" "$D/noctalia-$1.colors"; setp "$D/noctalia-$1.colors";;
            bounce*) if [ -n "$STARTED" ]; then cp "$D/noctalia.colors" "$D/noctalia-reload.colors"; setp "$D/noctalia-reload.colors"; sleep "${POKE#bounce}"; setp "$D/noctalia.colors"; fi;;
          esac; }
render dark; sleep 0.5
"${E[@]}" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=qt6ct ${BUILD:+QT_PLUGIN_PATH=$Q/${PLUG:-plug} LD_LIBRARY_PATH=$Q/${LIB:-lib}} "$S/kp/kp" $KCSM 2>/dev/null | while IFS= read -r l; do echo "$(date +%H:%M:%S.%1N) $l" >> "$LOG"; done &
sleep 3; STARTED=1
echo "$(date +%H:%M:%S.%1N) MAP $(grep -oE "/[^ ]*libqt6ct[^ ]*" /proc/$(pgrep -f "$S/kp/kp" | head -1)/maps | sort -u | tr "\n" " ")" >> "$LOG"
for m in light dark regen dark light; do ev "switch -> $m (render + notifyChange${POKE/nopoke/}${POKE/poke/ + qt6ct.conf re-saved})"; render $m; sleep 6; done
pkill -f "$S/kp/kp" ; sleep 0.3
echo "##### $N  format=$FMT  $POKE  $KCSM"; sed -E "s/ \| style=.*//" "$LOG"
