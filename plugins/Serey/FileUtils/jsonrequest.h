#pragma once

#include <QObject>
#include <QJSValue>
#include <QUrl>

class QNetworkAccessManager;

// HTTP with JSON body for any method; QML XHR drops DELETE bodies
class JsonRequest : public QObject
{
    Q_OBJECT
public:
    explicit JsonRequest(QObject *parent = nullptr);

    // callback(status, responseText); status 0 = network error
    Q_INVOKABLE void send(const QString &method, const QUrl &url, const QString &token,
                          const QString &json, const QJSValue &callback, int timeoutMs = 20000);

private:
    QNetworkAccessManager *m_nam;
};
