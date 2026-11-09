#pragma once

#include <QObject>
#include <QString>
#include <QUrl>

// file ops in the app's data dir
class AppFiles : public QObject
{
    Q_OBJECT

public:
    explicit AppFiles(QObject *parent = nullptr);

    // move into ~/.local/share/<package>/<subdir>; new path, or "" on failure
    Q_INVOKABLE QString moveToAppData(const QUrl &src, const QString &subdir) const;
};
