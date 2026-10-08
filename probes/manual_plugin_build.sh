#!/bin/bash
# Rebuilds only the platform theme plugin inside an existing cmake build directory, without cmake:
# moc + the two changed translation units + the recorded link line.
set -euo pipefail
B="$1/src/qt6ct-qtplugin"; SRC="$2/src/qt6ct-qtplugin"; cd "$B"
F=CMakeFiles/qt6ct-qtplugin.dir/flags.make
DEF=$(sed -n 's/^CXX_DEFINES = //p' $F); INC=$(sed -n 's/^CXX_INCLUDES = //p' $F); FLG=$(sed -n 's/^CXX_FLAGS = //p' $F)
MOC=$(ls qt6ct-qtplugin_autogen/*/moc_qt6ctplatformtheme.cpp)
/usr/lib/qt6/moc $DEF ${INC//-isystem /-I} --include "$PWD/qt6ct-qtplugin_autogen/moc_predefs.h" "$SRC/qt6ctplatformtheme.h" -o "$MOC"
c++ $DEF $INC $FLG -c qt6ct-qtplugin_autogen/mocs_compilation.cpp -o CMakeFiles/qt6ct-qtplugin.dir/qt6ct-qtplugin_autogen/mocs_compilation.cpp.o
c++ $DEF $INC $FLG -c "$SRC/qt6ctplatformtheme.cpp" -o CMakeFiles/qt6ct-qtplugin.dir/qt6ctplatformtheme.cpp.o
bash -c "$(cat CMakeFiles/qt6ct-qtplugin.dir/link.txt)"
ls -la --time-style=+%T libqt6ct.so
