/*
 * NetworkManager.h — Talk to zaios-network service for WiFi management.
 */
#ifndef NETWORKMANAGER_H
#define NETWORKMANAGER_H

#include <QObject>
#include <QLocalSocket>
#include <QVariantList>

class NetworkManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool connected      READ connected      NOTIFY stateChanged)
    Q_PROPERTY(QString ssid        READ ssid           NOTIFY stateChanged)
    Q_PROPERTY(QString ip          READ ip             NOTIFY stateChanged)
    Q_PROPERTY(QString state       READ state          NOTIFY stateChanged)
    Q_PROPERTY(bool scanning       READ scanning       NOTIFY scanningChanged)
    Q_PROPERTY(QVariantList networks READ networks     NOTIFY networksChanged)

public:
    explicit NetworkManager(QObject *parent = nullptr);

    bool connected() const { return m_state == "COMPLETED"; }
    QString ssid() const   { return m_ssid; }
    QString ip() const     { return m_ip; }
    QString state() const  { return m_state; }
    bool scanning() const  { return m_scanning; }
    QVariantList networks() const { return m_networks; }

    Q_INVOKABLE void scan();
    Q_INVOKABLE void connect(const QString &ssid, const QString &psk);
    Q_INVOKABLE void disconnect();
    Q_INVOKABLE void refreshStatus();

signals:
    void stateChanged();
    void scanningChanged();
    void networksChanged();

private slots:
    void onReadyRead();
    void onConnected();
    void tryConnect();

private:
    void sendCommand(const QString &cmd);
    void handleResponse(const QString &line);

    QLocalSocket *m_sock;
    QByteArray m_buffer;
    QString m_ssid, m_ip, m_state;
    bool m_scanning;
    QVariantList m_networks;
};

#endif
