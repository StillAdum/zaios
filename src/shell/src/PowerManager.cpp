#include "PowerManager.h"
#include <QProcess>

PowerManager::PowerManager(QObject *parent) : QObject(parent), m_sys(nullptr) {}

void PowerManager::powerOff() {
    emit aboutToShutdown();
    QProcess::startDetached("shutdown", {"-h", "now"});
}

void PowerManager::reboot() {
    emit aboutToShutdown();
    QProcess::startDetached("reboot");
}

void PowerManager::suspend() {
    emit aboutToSuspend();
    QProcess::startDetached("systemctl", {"suspend"});
    // Fallback: echo mem > /sys/power/state
}

void PowerManager::lockScreen() {
    // The QML UI shows the lock screen via a signal.
    // Implementation could be: pause media + show lock overlay.
}
