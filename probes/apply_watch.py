# Applies the watcher change to a qt6ct tree (official master, or a tree that already has m_schemePath).
import sys, re
root = sys.argv[1]
def rw(p, f):
    s = open(p).read(); t = f(s); assert t != s, p; open(p, 'w').write(t)
def sub(s, old, new):
    assert s.count(old) == 1, (old[:50], s.count(old)); return s.replace(old, new)
cpp = root + '/src/qt6ct-qtplugin/qt6ctplatformtheme.cpp'
hdr = root + '/src/qt6ct-qtplugin/qt6ctplatformtheme.h'
def f_cpp(s):
    s = sub(s, '''    QFileSystemWatcher *watcher = new QFileSystemWatcher(this);
    watcher->addPath(Qt6CT::configPath());

    QTimer *timer = new QTimer(this);
    timer->setSingleShot(true);
    timer->setInterval(3000);
    connect(watcher, &QFileSystemWatcher::directoryChanged, timer, qOverload<>(&QTimer::start));
    connect(timer, &QTimer::timeout, this, &Qt6CTPlatformTheme::updateSettings);
}
''', '''    m_watcher = new QFileSystemWatcher(this);
    m_watcher->addPath(Qt6CT::configPath());
    watchSchemeFile();

    QTimer *timer = new QTimer(this);
    timer->setSingleShot(true);
    timer->setInterval(3000);
    connect(m_watcher, &QFileSystemWatcher::fileChanged, timer, qOverload<>(&QTimer::start));
    connect(m_watcher, &QFileSystemWatcher::directoryChanged, timer, [this, timer](const QString &path) {
        //the directory of the color scheme file is watched only to notice the file coming back
        if(path == Qt6CT::configPath() || watchSchemeFile())
            timer->start();
    });
    connect(timer, &QTimer::timeout, this, &Qt6CTPlatformTheme::updateSettings);
}

//the directory of the file, or the nearest one above it that exists
static QString nearestExistingDir(const QString &filePath)
{
    QString path = QFileInfo(filePath).absolutePath();
    while(!QFileInfo::exists(path) && path != QFileInfo(path).absolutePath())
        path = QFileInfo(path).absolutePath();
    return path;
}

//The color scheme file can change while qt6ct.conf stays untouched. A file that is replaced or
//removed drops out of the watcher, so the nearest existing directory is watched as well to add
//it back. Returns true if the file has just been added.
bool Qt6CTPlatformTheme::watchSchemeFile()
{
    if(!m_watcher)
        return false;

    //A directory can appear or vanish while its watch is being set up, so look again after adding
    //one. The rounds are limited: whatever is watched at the end reports the next change anyway.
    for(int round = 0; round < 5; ++round)
    {
        const QString dirPath = m_schemePath.isEmpty() ? QString() : nearestExistingDir(m_schemePath);
        QStringList stale;
        const QStringList files = m_watcher->files();
        for(const QString &path : files)
        {
            if(path != m_schemePath)
                stale << path;
        }
        const QStringList dirs = m_watcher->directories();
        for(const QString &path : dirs)
        {
            if(path != dirPath && path != Qt6CT::configPath())
                stale << path;
        }
        if(!stale.isEmpty())
            m_watcher->removePaths(stale);

        if(m_schemePath.isEmpty())
            return false;
        if(dirs.contains(dirPath) || (m_watcher->addPath(dirPath) && nearestExistingDir(m_schemePath) == dirPath))
            break;
    }

    if(m_watcher->files().contains(m_schemePath) || !QFileInfo::exists(m_schemePath))
        return false;
    return m_watcher->addPath(m_schemePath);
}
''')
    s = sub(s, '''    qCDebug(lqt6ct) << "updating settings..";
    readSettings();
    applySettings();
''', '''    qCDebug(lqt6ct) << "updating settings..";
    readSettings();
    watchSchemeFile();
    applySettings();
''')
    if 'm_schemePath' not in s.split('void Qt6CTPlatformTheme::readSettings()')[1]:
        s = sub(s, '''    QString schemePath = settings.value("color_scheme_path"_L1).toString();
    if(!schemePath.isEmpty() && settings.value("custom_palette"_L1, false).toBool())
    {
        schemePath = Qt6CT::resolvePath(schemePath); //replace environment variables
        m_palette = Qt6CT::loadColorScheme(schemePath, m_palette);
    }
''', '''    QString schemePath = settings.value("color_scheme_path"_L1).toString();
    m_schemePath.clear();
    if(!schemePath.isEmpty() && settings.value("custom_palette"_L1, false).toBool())
    {
        schemePath = Qt6CT::resolvePath(schemePath); //replace environment variables
        m_palette = Qt6CT::loadColorScheme(schemePath, m_palette);
        m_schemePath = schemePath;
    }
''')
    return s
def f_hdr(s):
    if 'class QStyle;\n' in s:
        s = sub(s, 'class QStyle;\n', 'class QFileSystemWatcher;\nclass QStyle;\n')
    else:
        s = sub(s, 'class Qt6CTPlatformTheme : public QObject', 'class QFileSystemWatcher;\n\nclass Qt6CTPlatformTheme : public QObject')
    if re.search(r'#ifdef QT_WIDGETS_LIB\n    void createFSWatcher\(\);\n    void updateSettings\(\);\n#endif\n', s):
        s = sub(s, '#ifdef QT_WIDGETS_LIB\n    bool hasWidgets();\n', '#ifdef QT_WIDGETS_LIB\n    bool hasWidgets();\n    bool watchSchemeFile();\n')
    else:
        s = sub(s, '    void readSettings();\n', '    void readSettings();\n    bool watchSchemeFile();\n')
    if 'm_schemePath' not in s:
        m = re.search(r'    QPalette m_palette;\n', s); assert m
        s = s[:m.end()] + '    QString m_schemePath;\n' + s[m.end():]
    m = re.search(r'    (QPalette|std::optional<QPalette>) m_palette;\n', s); assert m
    s = s[:m.end()] + '    QFileSystemWatcher *m_watcher = nullptr;\n' + s[m.end():]
    return s
rw(cpp, f_cpp); rw(hdr, f_hdr)
