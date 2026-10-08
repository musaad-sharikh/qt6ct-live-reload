import sys
p = sys.argv[1] + '/src/qt6ct-common/qt6ct.cpp'; s = open(p).read()
old = '''    if(isKColorScheme(filePath))
        return KColorScheme::createApplicationPalette(KSharedConfig::openConfig(filePath));
'''
new = '''    if(isKColorScheme(filePath))
    {
        //KSharedConfig instances are shared and cached, so a file that got new content has to be
        //parsed again. This instance is also the one KColorScheme reads.
        KSharedConfigPtr config = KSharedConfig::openConfig(filePath);
        config->reparseConfiguration();
        //Breeze keeps its own instance of the file for the tools area, opened with NoGlobals
        KSharedConfig::openConfig(filePath, KConfig::NoGlobals)->reparseConfiguration();
        return KColorScheme::createApplicationPalette(config);
    }
'''
assert s.count(old) == 1; open(p, 'w').write(s.replace(old, new))
