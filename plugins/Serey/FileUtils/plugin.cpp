#include <QQmlExtensionPlugin>
#include <qqml.h>

#include "filechunkreader.h"
#include "jsonrequest.h"

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
};

#include "plugin.moc"
