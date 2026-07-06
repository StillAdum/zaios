#include "SystemService.h"
#include <QFile>
#include <QTextStream>
#include <QTimer>
#include <QSysInfo>
#include <QProcess>
#include <QRegularExpression>
#include <sys/statvfs.h>

SystemService::SystemService(QObject *parent) : QObject(parent), m_cpu(0) {
    QTimer *t = new QTimer(this);
    t->setInterval(5000);
    connect(t, &QTimer::timeout, this, [this]() { refresh(); emit systemInfoChanged(); });
    t->start();
}

QString SystemService::kernelVersion() const {
    return QSysInfo::kernelVersion();
}

QString SystemService::hostname() const {
    QFile f("/etc/hostname");
    if (f.open(QIODevice::ReadOnly)) return QString::fromUtf8(f.readAll()).trimmed();
    return "zaios";
}

QString SystemService::uptime() const {
    QFile f("/proc/uptime");
    if (!f.open(QIODevice::ReadOnly)) return "0:00";
    QStringList parts = QString::fromUtf8(f.readAll()).split(' ');
    if (parts.isEmpty()) return "0:00";
    int secs = parts[0].toFloat();
    int h = secs / 3600;
    int m = (secs % 3600) / 60;
    int s = secs % 60;
    return QString("%1:%2:%3").arg(h).arg(m, 2, 10, QChar('0')).arg(s, 2, 10, QChar('0'));
}

int SystemService::cpuUsage() const {
    QFile f("/proc/stat");
    if (!f.open(QIODevice::ReadOnly)) return 0;
    QString line = QString::fromUtf8(f.readLine());
    QStringList parts = line.split(QRegularExpression("\\s+"), Qt::SkipEmptyParts);
    if (parts.size() < 5) return 0;
    qint64 user = parts[1].toLongLong();
    qint64 nice = parts[2].toLongLong();
    qint64 sys  = parts[3].toLongLong();
    qint64 idle = parts[4].toLongLong();
    qint64 total = user + nice + sys + idle;
    qint64 diffIdle = idle - m_prevIdle;
    qint64 diffTotal = total - m_prevTotal;
    m_prevIdle = idle;
    m_prevTotal = total;
    if (diffTotal == 0) return m_cpu;
    m_cpu = 100 - (diffIdle * 100 / diffTotal);
    return m_cpu;
}

int SystemService::memUsage() const {
    QFile f("/proc/meminfo");
    if (!f.open(QIODevice::ReadOnly)) return 0;
    qint64 total = 0, avail = 0;
    QTextStream in(&f);
    while (!in.atEnd()) {
        QString line = in.readLine();
        if (line.startsWith("MemTotal:"))     total = line.split(QRegularExpression("\\s+"))[1].toLongLong();
        else if (line.startsWith("MemAvailable:")) avail = line.split(QRegularExpression("\\s+"))[1].toLongLong();
    }
    if (total == 0) return 0;
    return 100 - (avail * 100 / total);
}

int SystemService::memTotalMb() const {
    QFile f("/proc/meminfo");
    if (!f.open(QIODevice::ReadOnly)) return 0;
    QString line = QString::fromUtf8(f.readLine());
    return line.split(QRegularExpression("\\s+"))[1].toInt() / 1024;
}

int SystemService::diskUsed() const {
    struct statvfs s;
    if (statvfs("/", &s) != 0) return 0;
    qint64 total = s.f_blocks * s.f_frsize;
    qint64 avail = s.f_bavail * s.f_frsize;
    if (total == 0) return 0;
    return 100 - (avail * 100 / total);
}

int SystemService::diskTotal() const {
    struct statvfs s;
    if (statvfs("/", &s) != 0) return 0;
    return (s.f_blocks * s.f_frsize) / (1024 * 1024 * 1024);  // GB
}

void SystemService::refresh() { /* properties re-evaluate on each access */ }
