#include "appfiles.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>

AppFiles::AppFiles(QObject *parent)
    : QObject(parent)
{
}

QString AppFiles::moveToAppData(const QUrl &src, const QString &subdir) const
{
    const QString from = src.isLocalFile() ? src.toLocalFile() : src.toString();
    // APP_ID = <package>_<app>_<version>
    const QString pkg = QString::fromLocal8Bit(qgetenv("APP_ID")).section('_', 0, 0);
    if (from.isEmpty() || pkg.isEmpty() || !QFileInfo(from).isFile())
        return QString();

    const QString dir = QDir::homePath() + "/.local/share/" + pkg + "/" + subdir;
    if (!QDir().mkpath(dir))
        return QString();
    const QString to = dir + "/" + QFileInfo(from).fileName();
    if (from == to)
        return to;
    QFile::remove(to);
    if (QFile::rename(from, to))
        return to;
    // other filesystem
    if (QFile::copy(from, to)) {
        QFile::remove(from);
        return to;
    }
    return QString();
}
