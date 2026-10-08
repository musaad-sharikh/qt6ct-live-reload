#!/bin/bash
# Sourced as the first line of scen.sh, dol.sh and extra2.sh: runs the calling script again on a session
# bus of its own that can activate no service, with an XDG_RUNTIME_DIR of its own and no display.
# A program on a private bus that still has the caller's XDG_RUNTIME_DIR is not isolated: a Qt program
# that is not offscreen asks that bus for org.freedesktop.portal.Desktop, the bus starts a second
# xdg-desktop-portal, and its xdg-document-portal unmounts the caller's $XDG_RUNTIME_DIR/doc to mount
# its own, which goes away with the bus. Flatpak then starts nothing until the caller's portal is restarted.
[ -n "$QT6CT_PROBE_ISOLATED" ] && return 0
I=$(mktemp -d "${TMPDIR:-/tmp}/qt6ct-probe.XXXXXX") || exit 1
mkdir -m 700 "$I/rt" || exit 1
cat > "$I/bus.conf" <<C
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <listen>unix:dir=$I</listen>
  <auth>EXTERNAL</auth>
  <policy context="default"><allow send_destination="*" eavesdrop="true"/><allow eavesdrop="true"/><allow own="*"/></policy>
</busconfig>
C
env -u WAYLAND_DISPLAY -u DISPLAY QT6CT_PROBE_ISOLATED=1 XDG_RUNTIME_DIR="$I/rt" dbus-run-session --config-file="$I/bus.conf" -- "$0" "$@"; RC=$?
if grep -qF " $I/" /proc/self/mountinfo; then echo "isolate.sh: something is still mounted under $I, left in place" >&2
else rm -rf --one-file-system "$I"; fi
exit $RC
