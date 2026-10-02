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

    // Drops every pooled connection (QML engine's + ours). After a long sleep the pool holds
    // dead sockets that hang requests forever; XHR abort() can't free them, only this can.
    Q_INVOKABLE void resetConnections();

private:
    QNetworkAccessManager *m_nam;
};
