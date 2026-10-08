#include <QApplication>
#include <QTimer>
#include <QPalette>
#include <QStyle>
#include <QTextStream>
#include <KColorScheme>
#include <KColorSchemeManager>
#include <KStyleManager>
#include <KSharedConfig>
int main(int argc, char **argv)
{
    QApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("dolphin"));
    KStyleManager::initStyle();
    if (app.arguments().contains(QStringLiteral("--kcsm")))
        KColorSchemeManager::instance();
    auto *out = new QTextStream(stdout);
    QString last;
    auto *t = new QTimer(&app);
    QObject::connect(t, &QTimer::timeout, [&] {
        const QPalette p = app.palette();
        KColorScheme view(QPalette::Active, KColorScheme::View);
        KColorScheme sel(QPalette::Active, KColorScheme::Selection);
        const QString cur = QStringLiteral("qpal.window=%1 qpal.base=%2 qpal.highlight=%3 | kcs.view.bg=%4 kcs.view.fg=%5 kcs.sel.bg=%6 | style=%7 path=%8")
            .arg(p.color(QPalette::Window).name(), p.color(QPalette::Base).name(), p.color(QPalette::Highlight).name(),
                 view.background().color().name(), view.foreground().color().name(), sel.background().color().name(),
                 app.style()->objectName(), app.property("KDE_COLOR_SCHEME_PATH").toString().section(QLatin1Char('/'), -1));
        if (cur != last) { last = cur; *out << "PAL " << cur << Qt::endl; }
    });
    t->start(250);
    return app.exec();
}
