import QtQuick
Item {
    SystemPalette { id: p; colorGroup: SystemPalette.Active }
    Component.onCompleted: { console.log("PALETTE window=" + p.window + " base=" + p.base + " text=" + p.text + " style=" + Qt.styleHints.colorScheme); Qt.quit() }
}
