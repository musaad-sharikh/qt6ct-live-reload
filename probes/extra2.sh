#!/bin/bash
# usage: extra2.sh <scratch> <name> <probe: kpk|kp|qml> <case> [stock]
S="$1"; N="$2"; PR="$3"; CASE="$4"; BUILD="${5:-patched}"; Q="$S/qtct"; K="$S/probe/kp"; D="$S/probe/dyn/src"
R="$K/$N"; rm -rf "$R"; H="$R/home"; mkdir -p "$H/.config/qt6ct/colors" "$H/.local/share/color-schemes"; LOG="$R/log.txt"
F="$H/.local/share/color-schemes/noctalia.colors"; G="$H/.local/share/color-schemes/other.colors"; cp "$D/dark.colors" "$F"; cp "$D/dark.colors" "$G"
C="$H/.config/qt6ct/qt6ct.conf"; sed -e "s|^color_scheme_path=.*|color_scheme_path=$F|" "$HOME/.config/qt6ct/qt6ct.conf" > "$C"
E=(env -i PATH="$PATH" HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" LANG=C.UTF-8 QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=qt6ct QT_FORCE_STDERR_LOGGING=1 QT_LOGGING_RULES="qt6ct.debug=true")
[ "$BUILD" = patched ] && E+=(QT_PLUGIN_PATH="$Q/${PLUG:-plug}" LD_LIBRARY_PATH="$Q/${LIB:-lib}")
case "$PR" in kpk) CMD=("$K/kp" --kcsm);; kp) CMD=("$K/kp");; qml) CMD=(/usr/lib/qt6/bin/qml --apptype widget "$S/probe/dyn/watch.qml");; esac
[ "$CASE" = late ] && rm -f "$F"
"${E[@]}" "${CMD[@]}" >> "$LOG" 2>&1 &
PID=$!
ev(){ echo "EVT $*" >> "$LOG"; }
watches(){ cat /proc/$PID/fdinfo/* 2>/dev/null | grep -c '^inotify'; }
inplace(){ cat "$D/$1.colors" > "$F"; }
rename(){ cp "$D/$1.colors" "$F.tmp" && mv "$F.tmp" "$F"; }
recreate(){ rm -f "$F"; sleep "${2:-0.2}"; cp "$D/$1.colors" "$F"; }
setp(){ sed "s|^color_scheme_path=.*|color_scheme_path=$1|" "$C" > "$H/.config/q.tmp" && mv "$H/.config/q.tmp" "$C"; }
sleep 3; ev "watches at start: $(watches); plugin: $(grep -oE "/[^ ]*platformthemes/libqt6ct.so" /proc/$PID/maps | sort -u | sed "s#.*/qtct/##")"
case "$CASE" in
  delete)  ev "file deleted (stays away 5 s)"; rm "$F"; sleep 5; ev "light: file recreated"; cp "$D/light.colors" "$F"; sleep 5; ev "dark: overwritten in place"; inplace dark; sleep 5;;
  stress)  i=0; for step in "inplace light" "rename dark" "recreate light" "inplace dark" "recreate light" "rename dark" "rename light" "inplace dark" "recreate light" "recreate dark" "inplace light" "rename dark"; do i=$((i+1)); ev "#$i $step"; $step; sleep 4.2; ev "   watches: $(watches)"; done;;
  churn)   ev "40 unrelated files created and removed in the scheme directory (must NOT reload)"; for i in $(seq 1 40); do : > "$(dirname "$F")/junk-$i.tmp"; sleep 0.05; rm "$(dirname "$F")/junk-$i.tmp"; sleep 0.05; done; sleep 4; ev "   reloads so far: $(grep -c 'updating settings' "$LOG"); watches: $(watches)"; ev "light: overwritten in place (must reload once)"; inplace light; sleep 5;;
  late)    ev "scheme file absent at start, created now as dark"; cp "$D/dark.colors" "$F"; sleep 5; ev "light: overwritten in place"; inplace light; sleep 5;;
  nativefull) NF="$H/.config/qt6ct/colors/n.conf"; mk(){ printf '[ColorScheme]\nactive_colors=%s\ndisabled_colors=%s\ninactive_colors=%s\n' "$2" "$2" "$2" > "$1"; }
           DK="#f2f3f2, #243022, #ffffff, #cacaca, #9f9f9f, #b8b8b8, #f2f3f2, #ffffff, #f2f3f2, #1b2419, #243022, #000000, #81e467, #1b2518, #81e467, #81e467, #243022, #243022, #243022, #f2f3f2, #f2f3f2, #81e467"
           LT="#191b18, #d6e0d3, #ffffff, #cacaca, #9f9f9f, #b8b8b8, #191b18, #ffffff, #191b18, #e3eae1, #d6e0d3, #000000, #156003, #ffffff, #156003, #156003, #d6e0d3, #d6e0d3, #d6e0d3, #191b18, #191b18, #156003"
           mk "$NF" "$DK"; setp "$NF"; sleep 5; ev "reloads after repoint: $(grep -c 'updating settings' "$LOG"); watches: $(watches)"
           ev "light: in place"; mk "$NF" "$LT"; sleep 4.5; ev "dark: replaced by rename"; mk "$NF.tmp" "$DK"; mv "$NF.tmp" "$NF"; sleep 4.5
           ev "light: deleted and recreated"; rm "$NF"; sleep 0.2; mk "$NF" "$LT"; sleep 4.5
           ev "40 unrelated files in the same directory (must NOT reload)"; for i in $(seq 1 40); do : > "$H/.config/qt6ct/colors/junk-$i"; sleep 0.05; rm "$H/.config/qt6ct/colors/junk-$i"; sleep 0.05; done; sleep 4; ev "reloads so far: $(grep -c 'updating settings' "$LOG"); watches: $(watches)"
           ev "dark: 10 writes within a second"; for c in "$LT" "$DK" "$LT" "$DK" "$LT" "$DK" "$LT" "$LT" "$LT" "$DK"; do mk "$NF" "$c"; sleep 0.1; done; sleep 5;;
  missingfile|missingdir|unreadable)
           mk(){ printf '[ColorScheme]\nactive_colors=%s\ndisabled_colors=%s\ninactive_colors=%s\n' "$2" "$2" "$2" > "$1"; }
           DK="#f2f3f2, #243022, #ffffff, #cacaca, #9f9f9f, #b8b8b8, #f2f3f2, #ffffff, #f2f3f2, #1b2419, #243022, #000000, #81e467, #1b2518, #81e467, #81e467, #243022, #243022, #243022, #f2f3f2, #f2f3f2, #81e467"
           LT="#191b18, #d6e0d3, #ffffff, #cacaca, #9f9f9f, #b8b8b8, #191b18, #ffffff, #191b18, #e3eae1, #d6e0d3, #000000, #156003, #ffffff, #156003, #156003, #d6e0d3, #d6e0d3, #d6e0d3, #191b18, #191b18, #156003"
           rl(){ echo "reloads=$(grep -c 'updating settings' "$LOG") watches=$(watches) warnings=$(grep -ci 'QFileSystemWatcher\|inotify' "$LOG")"; }
           case "$CASE" in
             missingfile) NF="$H/.config/qt6ct/colors/later.conf";;
             missingdir)  NF="$H/not/yet/there/later.conf";;
             unreadable)  NF="$H/.config/qt6ct/colors/locked.conf"; mk "$NF" "$DK"; chmod 000 "$NF";;
           esac
           ev "color_scheme_path -> $(basename "$(dirname "$NF")")/$(basename "$NF") ($CASE)"; setp "$NF"; sleep 5; ev "   $(rl)"
           case "$CASE" in
             missingfile) ev "file created (dark)"; mk "$NF" "$DK";;
             missingdir)  ev "directories and file created (dark)"; mkdir -p "$(dirname "$NF")"; mk "$NF" "$DK";;
             unreadable)  ev "replaced by a readable file (dark)"; mk "$NF.tmp" "$DK"; mv -f "$NF.tmp" "$NF";;
           esac
           sleep 5; ev "   $(rl)"; ev "overwritten in place (light)"; mk "$NF" "$LT"; sleep 5; ev "   $(rl)"
           ev "deleted"; rm -f "$NF"; sleep 5; ev "   $(rl)"; ev "created again (dark)"; mk "$NF" "$DK"; sleep 5;;
  flap)    mk(){ printf '[ColorScheme]\nactive_colors=%s\ndisabled_colors=%s\ninactive_colors=%s\n' "$2" "$2" "$2" > "$1"; }
           DK="#f2f3f2, #243022, #ffffff, #cacaca, #9f9f9f, #b8b8b8, #f2f3f2, #ffffff, #f2f3f2, #1b2419, #243022, #000000, #81e467, #1b2518, #81e467, #81e467, #243022, #243022, #243022, #f2f3f2, #f2f3f2, #81e467"
           LT="#191b18, #d6e0d3, #ffffff, #cacaca, #9f9f9f, #b8b8b8, #191b18, #ffffff, #191b18, #e3eae1, #d6e0d3, #000000, #156003, #ffffff, #156003, #156003, #d6e0d3, #d6e0d3, #d6e0d3, #191b18, #191b18, #156003"
           cpu(){ awk '{print $14+$15}' /proc/$PID/stat; }
           NF="$H/flap/a/b/c/later.conf"
           ( end=$((SECONDS+10)); n=0; while [ $SECONDS -lt $end ]; do mkdir -p "$H/flap/a/b/c"; rm -rf "$H/flap"; n=$((n+1)); done; echo "EVT    flapper finished after $n create/remove cycles" >> "$LOG" ) &
           FL=$!; sleep 1; c0=$(cpu); ev "color_scheme_path -> a path whose four directories are created and removed in a tight loop for 10 s"; setp "$NF"; sleep 5
           ev "   mid-flap: alive=$(kill -0 $PID 2>/dev/null && echo yes || echo NO) watches=$(watches) reloads=$(grep -c 'updating settings' "$LOG") threads=$(ls /proc/$PID/task | wc -l)"
           wait $FL; sleep 1; c1=$(cpu); ev "   after flap: alive=$(kill -0 $PID 2>/dev/null && echo yes || echo NO) watches=$(watches) cpu-ticks-used=$((c1-c0))"
           sleep 4; c2=$(cpu); ev "   4 s idle afterwards: cpu-ticks-used=$((c2-c1)) reloads=$(grep -c 'updating settings' "$LOG")"
           ev "directories and file created (dark)"; mkdir -p "$(dirname "$NF")"; mk "$NF" "$DK"; sleep 5; ev "   watches=$(watches) reloads=$(grep -c 'updating settings' "$LOG")"
           ev "overwritten in place (light)"; mk "$NF" "$LT"; sleep 5;;
  burst)   ev "10 writes within one second, ending on light"; for m in light dark light dark light dark light dark dark light; do inplace $m; sleep 0.1; done; sleep 6;;
  repoint) ev "qt6ct.conf repointed at other.colors (dark)"; setp "$G"; sleep 5; ev "   watches: $(watches)"; ev "old file rewritten to light (must NOT apply)"; inplace light; sleep 5; ev "other.colors rewritten to light (must apply)"; cat "$D/light.colors" > "$G"; sleep 5; ev "   watches: $(watches)";;
  native)  NF="$H/.config/qt6ct/colors/n.conf"; mk(){ printf '[ColorScheme]\nactive_colors=%s\ndisabled_colors=%s\ninactive_colors=%s\n' "$1" "$1" "$1" > "$NF"; }
           DK="#f2f3f2, #243022, #ffffff, #cacaca, #9f9f9f, #b8b8b8, #f2f3f2, #ffffff, #f2f3f2, #1b2419, #243022, #000000, #81e467, #1b2518, #81e467, #81e467, #243022, #243022, #243022, #f2f3f2, #f2f3f2, #81e467"
           LT="#191b18, #d6e0d3, #ffffff, #cacaca, #9f9f9f, #b8b8b8, #191b18, #ffffff, #191b18, #e3eae1, #d6e0d3, #000000, #156003, #ffffff, #156003, #156003, #d6e0d3, #d6e0d3, #d6e0d3, #191b18, #191b18, #156003"
           mk "$DK"; setp "$NF"; sleep 5; ev "native .conf rewritten to light"; mk "$LT"; sleep 5; ev "native .conf rewritten to dark"; mk "$DK"; sleep 5;;
esac
ev "probe alive: $(kill -0 $PID 2>/dev/null && echo yes || echo NO); watches at end: $(watches); reloads: $(grep -c 'updating settings' "$LOG")"; kill $PID 2>/dev/null; sleep 0.3
echo "##### $N  probe=$PR  case=$CASE  build=$BUILD"; sed -E 's/ \| style=.*//; s/qpal\.//g; s/kcs\.//g; s/^qml: //; s/PAL [0-9]{13} /PAL /' "$LOG" | grep -E 'PAL|EVT|rash|ASSERT|QFileSystemWatcher' | cut -c1-140
