/*
 * BluetoothManager.cpp — Talks to BlueZ over the system bus.
 *
 * Uses QtDBus to call org.bluez.Adapter1 methods (StartDiscovery, etc.),
 * and listens to org.freedesktop.DBus.ObjectManager.InterfacesAdded to
 * detect new devices.
 */
#include "BluetoothManager.h"
#include <QDBusConnection>
#include <QDBusReply>
#include <QDBusArgument>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDebug>
#include <QTimer>
#include <QVariantMap>

static const QString BLUEZ_SERVICE = "org.bluez";
static const QString BLUEZ_MANAGER_PATH = "/";

BluetoothManager::BluetoothManager(QObject *parent)
    : QObject(parent), m_managerIface(nullptr), m_adapterIface(nullptr),
      m_powered(false), m_scanning(false), m_findRetryCount(0)
{
    QDBusConnection bus = QDBusConnection::systemBus();

    m_managerIface = new QDBusInterface(BLUEZ_SERVICE, BLUEZ_MANAGER_PATH,
                                        "org.freedesktop.DBus.ObjectManager", bus, this);

    // Listen for new devices
    bus.connect(BLUEZ_SERVICE, BLUEZ_MANAGER_PATH,
                "org.freedesktop.DBus.ObjectManager",
                "InterfacesAdded",
                this, SLOT(onDeviceAdded(QDBusObjectPath)));

    bus.connect(BLUEZ_SERVICE, BLUEZ_MANAGER_PATH,
                "org.freedesktop.DBus.ObjectManager",
                "InterfacesRemoved",
                this, SLOT(onDeviceRemoved(QDBusObjectPath)));

    // Find adapter (retry until bluetoothd is up)
    QTimer::singleShot(2000, this, [this]() { findAdapter(); });
}

void BluetoothManager::findAdapter() {
    QDBusConnection bus = QDBusConnection::systemBus();
    // GetManagedObjects returns a{oa{sa{sv}}} directly (NOT a variant)
    QDBusMessage reply = m_managerIface->call("GetManagedObjects");
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty()) {
        // Exponential backoff: 5s, 10s, 20s, 30s (cap)
        int next = qMin(30, 5 * (1 << m_findRetryCount));
        if (m_findRetryCount < 6) {
            qWarning() << "Bluetooth: GetManagedObjects failed, retry " << m_findRetryCount << "in" << next << "s";
            m_findRetryCount++;
            QTimer::singleShot(next * 1000, this, [this]() { findAdapter(); });
        } else {
            // Give up — most VMs and many TVs have no BT adapter
            qDebug() << "Bluetooth: giving up after" << m_findRetryCount << "retries (no adapter or bluetoothd not running)";
        }
        return;
    }
    m_findRetryCount = 0;

    // Find first object that implements org.bluez.Adapter1
    QVariantMap objects = parseManagedObjects(reply.arguments().at(0));
    if (objects.isEmpty()) {
        // No managed objects — bluez is running but has no adapter
        // Don't keep retrying; only re-check when bluez emits InterfacesAdded
        qDebug() << "Bluetooth: bluez running but no managed objects (no adapter present)";
        return;
    }

    for (const QString &path : objects.keys()) {
        QVariantMap ifaces = objects[path].toMap();
        if (ifaces.contains("org.bluez.Adapter1")) {
            m_adapterPath = path;
            m_adapterIface = new QDBusInterface(BLUEZ_SERVICE, path,
                                               "org.bluez.Adapter1", bus, this);
            // Get current powered state
            QVariant pwr = m_adapterIface->property("Powered");
            if (pwr.isValid()) {
                m_powered = pwr.toBool();
                emit poweredChanged();
            }
            emit adapterChanged();
            qDebug() << "Bluetooth: adapter found at" << path << "powered=" << m_powered;
            refreshDevices();
            return;
        }
    }
    // BlueZ is running, no error, but no adapter — stop retrying
    qDebug() << "Bluetooth: bluez running but no adapter present (this is normal for VMs)";
}

void BluetoothManager::refreshDevices() {
    if (!m_adapterIface) return;
    QDBusMessage reply = m_managerIface->call("GetManagedObjects");
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty()) return;

    QVariantMap objects = parseManagedObjects(reply.arguments().at(0));

    QVariantList newList;
    for (const QString &path : objects.keys()) {
        QVariantMap ifaces = objects[path].toMap();
        if (ifaces.contains("org.bluez.Device1")) {
            QVariantMap props = ifaces["org.bluez.Device1"].toMap();
            QVariantMap dev;
            dev["path"]      = path;
            dev["address"]   = props.value("Address");
            dev["name"]      = props.value("Name");
            dev["connected"] = props.value("Connected");
            dev["paired"]    = props.value("Paired");
            dev["trusted"]   = props.value("Trusted");
            dev["rssi"]      = props.value("RSSI");
            dev["icon"]      = props.value("Icon");
            newList << dev;
        }
    }
    if (newList != m_devices) {
        m_devices = newList;
        emit devicesChanged();
    }
}

void BluetoothManager::onPropertiesChanged(const QString &interface,
                                            const QVariantMap &changed,
                                            const QStringList &invalidated) {
    Q_UNUSED(invalidated)
    if (interface == "org.bluez.Adapter1") {
        if (changed.contains("Powered")) {
            m_powered = changed.value("Powered").toBool();
            emit poweredChanged();
        }
        if (changed.contains("Discovering")) {
            m_scanning = changed.value("Discovering").toBool();
            emit scanningChanged();
        }
    } else if (interface == "org.bluez.Device1") {
        refreshDevices();
    }
}

void BluetoothManager::onDeviceAdded(const QDBusObjectPath &path) {
    Q_UNUSED(path)
    refreshDevices();
}

void BluetoothManager::onDeviceRemoved(const QDBusObjectPath &path) {
    Q_UNUSED(path)
    refreshDevices();
}

void BluetoothManager::setPowered(bool on) {
    if (!m_adapterIface) return;
    m_adapterIface->setProperty("Powered", on);
    m_powered = on;
    emit poweredChanged();
}

void BluetoothManager::startScan() {
    if (!m_adapterIface || m_scanning) return;
    m_adapterIface->call("StartDiscovery");
    m_scanning = true;
    emit scanningChanged();
    // Auto-stop after 15s
    QTimer::singleShot(15000, this, [this]() {
        stopScan();
        refreshDevices();
    });
}

void BluetoothManager::stopScan() {
    if (!m_adapterIface) return;
    m_adapterIface->call("StopDiscovery");
    m_scanning = false;
    emit scanningChanged();
}

void BluetoothManager::pair(const QString &devicePath) {
    QDBusInterface devIface(BLUEZ_SERVICE, devicePath, "org.bluez.Device1",
                            QDBusConnection::systemBus(), this);
    QDBusReply<void> reply = devIface.call("Pair");
    if (!reply.isValid()) {
        qWarning() << "Pair failed:" << reply.error();
    }
    refreshDevices();
}

void BluetoothManager::connectToDevice(const QString &devicePath) {
    QDBusInterface devIface(BLUEZ_SERVICE, devicePath, "org.bluez.Device1",
                            QDBusConnection::systemBus(), this);
    QDBusReply<void> reply = devIface.call("Connect");
    if (!reply.isValid()) {
        qWarning() << "Connect failed:" << reply.error();
    }
    refreshDevices();
    emit deviceConnected(devicePath);
}

void BluetoothManager::disconnectFromDevice(const QString &devicePath) {
    QDBusInterface devIface(BLUEZ_SERVICE, devicePath, "org.bluez.Device1",
                            QDBusConnection::systemBus(), this);
    devIface.call("Disconnect");
    refreshDevices();
    emit deviceDisconnected(devicePath);
}

void BluetoothManager::remove(const QString &devicePath) {
    if (!m_adapterIface) return;
    m_adapterIface->call("RemoveDevice", QVariant::fromValue(QDBusObjectPath(devicePath)));
    refreshDevices();
}

void BluetoothManager::trust(const QString &devicePath) {
    QDBusInterface devIface(BLUEZ_SERVICE, devicePath, "org.bluez.Device1",
                            QDBusConnection::systemBus(), this);
    devIface.setProperty("Trusted", true);
    refreshDevices();
}

// static
QVariantMap BluetoothManager::parseManagedObjects(const QVariant &argVar) {
    // GetManagedObjects returns a{oa{sa{sv}}}
    // Each key is an object path (string), each value is a{sa{sv}} (QVariantMap of QVariantMap)
    QVariantMap result;
    const QDBusArgument *arg = nullptr;
    QDBusArgument localArg;

    if (argVar.canConvert<QDBusArgument>()) {
        localArg = argVar.value<QDBusArgument>();
        arg = &localArg;
    } else {
        return result;
    }

    arg->beginMap();
    while (!arg->atEnd()) {
        QString path;
        QVariantMap ifaces;
        arg->beginMapEntry();
        *arg >> path;
        *arg >> ifaces;
        arg->endMapEntry();
        result[path] = ifaces;
    }
    arg->endMap();
    return result;
}
