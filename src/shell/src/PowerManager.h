/*
 * PowerManager.h — Power state control (suspend, reboot, poweroff).
 * Talks to our init (zaios-init) via signals.
 */
#ifndef POWERMANAGER_H
#define POWERMANAGER_H

#include <QObject>

class SystemService;

class PowerManager : public QObject {
    Q_OBJECT
public:
    explicit PowerManager(QObject *parent = nullptr);

    void setSystem(SystemService *s) { m_sys = s; }

    Q_INVOKABLE void powerOff();
    Q_INVOKABLE void reboot();
    Q_INVOKABLE void suspend();
    Q_INVOKABLE void lockScreen();

signals:
    void aboutToSuspend();
    void aboutToShutdown();

private:
    SystemService *m_sys;
};

#endif
