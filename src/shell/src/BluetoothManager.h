/*
 * BluetoothManager.h — BlueZ wrapper via QtDBus.
 *
 * Exposes scan / pair / connect / disconnect operations to QML.
 * Uses org.bluez DBus interface (started by init as bluetoothd).
 */
#ifndef BLUETOOTHMANAGER_H
#define BLUETOOTHMANAGER_H

#include <QObject>
#include <QDBusInterface>
#include <QDBusPendingCallWatcher>
#include <QVariantList>

class BluetoothManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool         powered     READ powered     NOTIFY poweredChanged)
    Q_PROPERTY(bool         scanning    READ scanning    NOTIFY scanningChanged)
    Q_PROPERTY(QVariantList devices     READ devices     NOTIFY devicesChanged)
    Q_PROPERTY(QString      adapterPath READ adapterPath NOTIFY adapterChanged)

public:
    explicit BluetoothManager(QObject *parent = nullptr);

    bool         powered() const  { return m_powered; }
    bool         scanning() const { return m_scanning; }
    QVariantList devices() const  { return m_devices; }
    QString      adapterPath() const { return m_adapterPath; }

    Q_INVOKABLE void setPowered(bool on);
    Q_INVOKABLE void startScan();
    Q_INVOKABLE void stopScan();
    Q_INVOKABLE void pair(const QString &devicePath);
    Q_INVOKABLE void connectToDevice(const QString &devicePath);
    Q_INVOKABLE void disconnectFromDevice(const QString &devicePath);
    Q_INVOKABLE void remove(const QString &devicePath);
    Q_INVOKABLE void trust(const QString &devicePath);

signals:
    void poweredChanged();
    void scanningChanged();
    void devicesChanged();
    void adapterChanged();
    void pairRequest(const QString &address, const QString &name);
    void pinRequest(const QString &address);
    void deviceConnected(const QString &address);
    void deviceDisconnected(const QString &address);

private slots:
    void onPropertiesChanged(const QString &interface,
                             const QVariantMap &changed,
                             const QStringList &invalidated);
    void onDeviceAdded(const QDBusObjectPath &path);
    void onDeviceRemoved(const QDBusObjectPath &path);

private:
    void findAdapter();
    void refreshDevices();
    QDBusInterface *m_managerIface;
    QDBusInterface *m_adapterIface;
    QString  m_adapterPath;
    bool     m_powered;
    bool     m_scanning;
    QVariantList m_devices;
};

#endif
