/*
 * NotificationManager.h — Toast / banner notification system.
 */
#ifndef NOTIFICATIONMANAGER_H
#define NOTIFICATIONMANAGER_H

#include <QObject>
#include <QVariantList>

class NotificationManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList notifications READ notifications NOTIFY notificationsChanged)

public:
    explicit NotificationManager(QObject *parent = nullptr);

    QVariantList notifications() const { return m_notifications; }

    // severity: "info" | "warning" | "error" | "success"
    Q_INVOKABLE void show(const QString &title, const QString &body = QString(),
                          const QString &severity = "info", int durationMs = 4000);
    Q_INVOKABLE void dismiss(int id);

signals:
    void notificationsChanged();
    void notificationShown(int id, const QString &title, const QString &body, const QString &severity);

private:
    QVariantList m_notifications;
    int m_nextId = 1;
};

#endif
