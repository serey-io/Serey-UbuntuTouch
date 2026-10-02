#include "netpool.h"

#include <QCoreApplication>
#include <QMutex>
#include <QNetworkAccessManager>
#include <QQmlEngine>
#include <QThread>

namespace {
QMutex s_mutex;
QList<QNetworkAccessManager *> s_nams;
}

void NetPool::install(QQmlEngine *engine)
{
    engine->setNetworkAccessManagerFactory(new NetPool(engine->networkAccessManagerFactory()));
}

QNetworkAccessManager *NetPool::create(QObject *parent)
{
    QNetworkAccessManager *nam = m_previous ? m_previous->create(parent)
                                            : new QNetworkAccessManager(parent);
    // Image loader: a hung image holds one of its 8 slots forever, so later images never
    // load. An inactivity timeout frees it (measured: works here, unlike XHR's own timeout).
    // XHR keeps Http.js's per-request deadlines; its slots only free via resetAll().
    // create() runs on the thread the NAM lives on; anything off the main thread is the loader.
    if (QThread::currentThread() != QCoreApplication::instance()->thread())
        nam->setTransferTimeout(15000);

    QMutexLocker lock(&s_mutex);
    s_nams.append(nam);
    QObject::connect(nam, &QObject::destroyed, [nam]() {
        QMutexLocker l(&s_mutex);
        s_nams.removeAll(nam);
    });
    return nam;
}

void NetPool::resetAll()
{
    QMutexLocker lock(&s_mutex);
    for (QNetworkAccessManager *nam : qAsConst(s_nams)) {
        // Same thread: clear now, so the request that triggered this goes out on a fresh pool.
        // Other threads: queue it there; the call is dropped if the NAM dies first.
        if (nam->thread() == QThread::currentThread())
            nam->clearConnectionCache();
        else
            QMetaObject::invokeMethod(nam, [nam]() { nam->clearConnectionCache(); },
                                      Qt::QueuedConnection);
    }
}
