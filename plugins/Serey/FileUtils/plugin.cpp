#include <QQmlExtensionPlugin>
#include <qqml.h>

#include "filechunkreader.h"
#include "jsonrequest.h"
#include "netpool.h"

class SereyFileUtilsPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface")

public:
    void registerTypes(const char *uri) override
    {
        // import Serey.FileUtils 1.0
        qmlRegisterType<FileChunkReader>(uri, 1, 0, "FileChunkReader");
        qmlRegisterType<JsonRequest>(uri, 1, 0, "JsonRequest");
    }

    // Runs on `import Serey.FileUtils`, before any image loads, so the loader's NAM is tracked.
    void initializeEngine(QQmlEngine *engine, const char *uri) override
    {
        Q_UNUSED(uri)
        NetPool::install(engine);
    }
};

#include "plugin.moc"
