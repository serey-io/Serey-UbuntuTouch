#include "jsonrequest.h"
#include "netpool.h"

#include <QBuffer>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QQmlEngine>
#include <QTimer>

JsonRequest::JsonRequest(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
}

void JsonRequest::resetConnections()
{
    // Measured 0ms: tears down the HTTP thread, the next request opens fresh sockets.
    // The engine's own NAM is cleared directly too, in case it predates NetPool's factory.
    if (QQmlEngine *engine = qmlEngine(this))
        engine->networkAccessManager()->clearConnectionCache();
    NetPool::resetAll();
    m_nam->clearConnectionCache();
}

void JsonRequest::send(const QString &method, const QUrl &url, const QString &token,
                       const QString &json, const QJSValue &callback, int timeoutMs)
{
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    req.setRawHeader("Accept", "application/json");
    if (!token.isEmpty())
        req.setRawHeader("Authorization", "Bearer " + token.toUtf8());

    // Custom request keeps the body for any verb
    QBuffer *body = new QBuffer;
    body->setData(json.toUtf8());
    body->open(QIODevice::ReadOnly);
    QNetworkReply *reply = m_nam->sendCustomRequest(req, method.toUtf8(), body);
    body->setParent(reply);

    // Timeout guard
    QTimer *timer = new QTimer(reply);
    timer->setSingleShot(true);
    connect(timer, &QTimer::timeout, reply, &QNetworkReply::abort);
    timer->start(timeoutMs);

    QJSValue cb = callback;
    connect(reply, &QNetworkReply::finished, this, [reply, cb]() mutable {
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QString text = QString::fromUtf8(reply->readAll());
        reply->deleteLater();
        if (cb.isCallable())
            cb.call(QJSValueList() << status << text);
    });
}
