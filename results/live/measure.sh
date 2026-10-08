#!/bin/bash
# usage: measure.sh <label>   -- read-only: captures the Dolphin window rectangle and samples it
B="$(dirname "$0")"; L="$1"; NC=~/.local/share/color-schemes/noctalia.colors
geo=$(niri msg -j windows | python3 -I -c "
import json,sys
ws=json.load(sys.stdin); d=[w for w in ws if w['id']==62]
if not d: print('GONE'); sys.exit()
d=d[0]; col=d['layout']['pos_in_scrolling_layout'][0]; tw,th=d['layout']['tile_size']
same=[w for w in ws if w['workspace_id']==d['workspace_id'] and w['layout']['pos_in_scrolling_layout']]
ncols=max(w['layout']['pos_in_scrolling_layout'][0] for w in same)
print(d['workspace_id'], col, ncols, int(tw), int(th), 'active' if d['is_focused'] else 'inactive', d.get('pid'))")
echo "window 62: workspace/col/ncols/w/h/focus/pid = $geo"
[ "$geo" = GONE ] && exit 1
set -- $geo; WS=$1; COL=$2; W=$4; H=$5; FOCUS=$6
act=$(niri msg -j workspaces | python3 -I -c "import json,sys;print([w['id'] for w in json.load(sys.stdin) if w.get('is_active')])")
echo "active workspaces: $act (window on $WS)"
case "$act" in *"[$WS]"*|*"[$WS,"*|*", $WS]"*|*", $WS,"*) ;; *) echo "NOT VISIBLE: the Dolphin workspace is not on screen, nothing captured"; exit 2;; esac
X=$((16 + (COL-1)*(W+16)))
# the toolbar strip of two captures 0.8 s apart must be identical (hover effects in the file view are
# allowed to differ), and the workspace and focus state must be unchanged:
# a workspace switch in progress shows parts of other windows inside this rectangle
grim -g "$X,54 ${W}x${H}" "$B/.cap1.png" || exit 1
sleep 0.8
grim -g "$X,54 ${W}x${H}" "$B/.cap2.png" || exit 1
act2=$(niri msg -j workspaces | python3 -I -c "import json,sys;print([w['id'] for w in json.load(sys.stdin) if w.get('is_active')])")
foc2=$(niri msg -j windows | python3 -I -c "import json,sys;print(['active' if w['is_focused'] else 'inactive' for w in json.load(sys.stdin) if w['id']==62][0])")
if [ "$act" != "$act2" ] || [ "$FOCUS" != "$foc2" ] || [ "$(magick compare -metric AE \( "$B/.cap1.png" -crop 930x56+0+0 +repage \) \( "$B/.cap2.png" -crop 930x56+0+0 +repage \) null: 2>&1 | awk '{print int($1)}')" != 0 ]; then
  rm -f "$B/.cap1.png" "$B/.cap2.png"; echo "UNSTABLE: the screen changed during the capture (workspace switch, focus change or animation); captures discarded unread"; exit 3
fi
mv "$B/.cap1.png" "$B/dolphin-$L.png"; rm -f "$B/.cap2.png"
python3 -I - "$B/dolphin-$L.png" "$NC" "$FOCUS" <<'PY'
import sys, re
from PIL import Image
import numpy as np
from collections import Counter
im = np.array(Image.open(sys.argv[1]).convert('RGB')); h, w, _ = im.shape
hx = lambda c: '#%02x%02x%02x' % tuple(int(v) for v in c)
sch = {}; sec = None
for line in open(sys.argv[2]):
    line = line.strip()
    if line.startswith('['): sec = line
    elif '=' in line and sec:
        k, v = line.split('=', 1)
        if re.fullmatch(r'\d+,\d+,\d+', v): sch[(sec, k)] = hx(v.split(','))
focus = sys.argv[3]
exp_view = sch[('[Colors:View]', 'BackgroundNormal')]
exp_tool = sch[('[Colors:Header]', 'BackgroundNormal')] if focus == 'active' else sch[('[Colors:Header][Inactive]', 'BackgroundNormal')]
def patch(x, y, r=4):
    p = im[y-r:y+r+1, x-r:x+r+1].reshape(-1, 3); c = Counter(map(tuple, p)); top, n = c.most_common(1)[0]
    return hx(top), n, len(p)
print(f'capture {w}x{h}, window is {focus}')
print(f'expected from noctalia.colors: view={exp_view}  toolbar({focus})={exp_tool}')
ok = True
for name, pts, exp in (('file view', ((240,100),(450,280),(30,300),(660,620),(450,790),(25,960)), exp_view), ('toolbar', ((195,8),(8,28),(878,50),(845,8)), exp_tool)):
    for x, y in pts:
        c, n, t = patch(x, y); m = (c == exp); ok &= m
        print(f'  {name:<10} ({x:>3},{y:>3}) {c} uniform={n}/{t} {"match" if m else "MISMATCH"}')
c = Counter(map(tuple, im.reshape(-1, 3))); tot = h*w
print('  most common:', ', '.join(f'{hx(col)} {100*n/tot:.1f}%' for col, n in c.most_common(4)))
print('RESULT:', 'all samples match' if ok else 'MISMATCH')
PY
