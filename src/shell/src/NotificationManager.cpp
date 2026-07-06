#include "NotificationManager.h"
#include <QTimer>
#include <QDateTime>

NotificationManager::NotificationManager(QObject *parent) : QObject(parent) {}

void NotificationManager::show(const QString &title, const QString &body,
                                const QString &severity, int durationMs) {
    QVariantMap n;
    int id = m_nextId++;
    n["id"] = id;
    n["title"] = title;
    n["body"] = body;
    n["severity"] = severity;
    n["time"] = QDateTime::currentDateTime().toString("HH:mm");
    m_notifications.prepend(n);
    if (m_notifications.size() > 8) m_notifications = m_notifications.mid(0, 8);
    emit notificationsChanged();
    emit notificationShown(id, title, body, severity);

    // Auto-dismiss after durationMs
    QTimer::singleShot(durationMs, this, [this, id]() { dismiss(id); });
}

void NotificationManager::dismiss(int id) {
    QVariantList nl;
    for (const QVariant &v : m_notifications) {
        if (v.toMap().value("id").toInt() != id) nl << v;
    }
    if (nl.size() != m_notifications.size()) {
        m_notifications = nl;
        emit notificationsChanged();
    }
}
