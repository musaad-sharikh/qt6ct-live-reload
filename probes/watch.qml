import QtQuick
Item {
    SystemPalette { id: p; colorGroup: SystemPalette.Active }
    property string last: ""
    function cur() { return "window=" + p.window + " base=" + p.base + " text=" + p.text }
    Timer { interval: 250; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { var c = cur(); if (c !== last) { last = c; console.log("PAL " + Date.now() + " " + c) } } }
    Timer { interval: 45000; running: true; onTriggered: Qt.quit() }
}
