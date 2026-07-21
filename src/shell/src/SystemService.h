/*
 * SystemService.h — system info: CPU, RAM, disk, uptime, kernel version.
 */
#ifndef SYSTEMSERVICE_H
#define SYSTEMSERVICE_H

#include <QObject>

class SystemService : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString osName       READ osName       CONSTANT)
    Q_PROPERTY(QString osVersion    READ osVersion    CONSTANT)
    Q_PROPERTY(QString kernelVersion READ kernelVersion CONSTANT)
    Q_PROPERTY(QString hostname     READ hostname     NOTIFY systemInfoChanged)
    Q_PROPERTY(QString uptime       READ uptime       NOTIFY systemInfoChanged)
    Q_PROPERTY(int     cpuUsage     READ cpuUsage     NOTIFY systemInfoChanged)
    Q_PROPERTY(int     memUsage     READ memUsage     NOTIFY systemInfoChanged)
    Q_PROPERTY(int     memTotalMb   READ memTotalMb   CONSTANT)
    Q_PROPERTY(int     diskUsed     READ diskUsed     NOTIFY systemInfoChanged)
    Q_PROPERTY(int     diskTotal    READ diskTotal    CONSTANT)

public:
    explicit SystemService(QObject *parent = nullptr);

    QString osName() const        { return "ZAIos"; }
    QString osVersion() const     { return ZAIOS_SHELL_VERSION; }
    QString kernelVersion() const;
    QString hostname() const;
    QString uptime() const;
    int     cpuUsage() const;
    int     memUsage() const;
    int     memTotalMb() const;
    int     diskUsed() const;
    int     diskTotal() const;

    Q_INVOKABLE void refresh();

    // Battery detection — returns -1 if no battery present
    Q_INVOKABLE int batteryCapacity() const;
    Q_INVOKABLE bool batteryCharging() const;

signals:
    void systemInfoChanged();

private:
    mutable int m_cpu;
    mutable qint64 m_prevIdle;
    mutable qint64 m_prevTotal;
};

#endif
