// Preloaded into an unmodified Dolphin: reports the live palette and saves a picture of the main window.
#include <QApplication>
#include <QTimer>
#include <QWidget>
#include <QPixmap>
#include <QPalette>
#include <KColorScheme>
#include <cstdio>
static void shoot(int n)
{
    const QString dir = QString::fromLocal8Bit(qgetenv("PROBE_OUT"));
    for (QWidget *w : QApplication::topLevelWidgets()) {
        if (w->isVisible() && w->inherits("QMainWindow"))
            w->grab().save(QStringLiteral("%1/shot-%2.png").arg(dir).arg(n));
    }
}
static void start()
{
    if (!qobject_cast<QApplication *>(qApp))
        return;
    auto *t = new QTimer(qApp);
    QObject::connect(t, &QTimer::timeout, [] {
        static QString last;
        static int n = 0;
        const QPalette p = qApp->palette();
        KColorScheme view(QPalette::Active, KColorScheme::View);
        const QString cur = QStringLiteral("window=%1 base=%2 highlight=%3 | view.bg=%4 view.fg=%5")
            .arg(p.color(QPalette::Window).name(), p.color(QPalette::Base).name(), p.color(QPalette::Highlight).name(),
                 view.background().color().name(), view.foreground().color().name());
        if (cur != last) {
            last = cur;
            const int id = n++;
            fprintf(stderr, "PAL shot-%d %s\n", id, qPrintable(cur));
            fflush(stderr);
            QTimer::singleShot(1200, qApp, [id] { shoot(id); });
        }
    });
    t->start(250);
}
Q_COREAPP_STARTUP_FUNCTION(start)
