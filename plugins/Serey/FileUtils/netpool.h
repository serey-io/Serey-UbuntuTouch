#pragma once

#include <QQmlNetworkAccessManagerFactory>

class QQmlEngine;

// Tracks every QNetworkAccessManager the QML engine creates (XHR on the main thread, the
// image loader in its own thread) so a dead connection pool can be dropped after the phone
// sleeps. See Http.resetConnections() in qml/services/Http.js.
class NetPool : public QQmlNetworkAccessManagerFactory
{
public:
    // Wraps whatever factory is already set, so we never replace someone else's.
    static void install(QQmlEngine *engine);
    // Drops every tracked pool, each on its own thread. Measured 0ms on the main thread.
    static void resetAll();

    QNetworkAccessManager *create(QObject *parent) override;

private:
    explicit NetPool(QQmlNetworkAccessManagerFactory *previous) : m_previous(previous) {}
    QQmlNetworkAccessManagerFactory *m_previous;
};
