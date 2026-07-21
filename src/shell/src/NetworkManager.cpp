/*
 * NetworkManager.cpp — Connects to /run/zaios/network.sock and exposes
 * WiFi scan/connect/state to QML.
 */
#include "NetworkManager.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QTimer>
#include <QDebug>

#define SOCK_PATH "/run/zaios/network.sock"

NetworkManager::NetworkManager(QObject *parent)
    : QObject(parent), m_sock(new QLocalSocket(this)),
      m_scanning(false)
{
    connect(m_sock, &QLocalSocket::connected, this, &NetworkManager::onConnected);
    connect(m_sock, &QLocalSocket::readyRead, this, &NetworkManager::onReadyRead);
    connect(m_sock, &QLocalSocket::disconnected, this, [this]() {
        qDebug() << "Network: socket disconnected, retrying in 2s";
        QTimer::singleShot(2000, this, &NetworkManager::tryConnect);
    });

    // Try initial connect
    QTimer::singleShot(1000, this, &NetworkManager::tryConnect);

    // Periodic status refresh
    QTimer *statusTimer = new QTimer(this);
    statusTimer->setInterval(5000);
    connect(statusTimer, &QTimer::timeout, this, &NetworkManager::refreshStatus);
    statusTimer->start();
}

void NetworkManager::tryConnect() {
    if (m_sock->state() == QLocalSocket::ConnectedState) return;
    m_sock->connectToServer(SOCK_PATH);
}

void NetworkManager::onConnected() {
    qDebug() << "Network: connected to service";
    refreshStatus();
}

void NetworkManager::sendCommand(const QString &cmd) {
    if (m_sock->state() != QLocalSocket::ConnectedState) {
        // Silent — too noisy to log every poll. The reconnect logic in onDisconnected handles retries.
        return;
    }
    m_sock->write((cmd + "\n").toUtf8());
    m_sock->flush();
}

void NetworkManager::onReadyRead() {
    m_buffer.append(m_sock->readAll());
    int idx;
    while ((idx = m_buffer.indexOf('\n')) >= 0) {
        QByteArray line = m_buffer.left(idx);
        m_buffer = m_buffer.mid(idx + 1);
        handleResponse(QString::fromUtf8(line));
    }
}

void NetworkManager::handleResponse(const QString &line) {
    QJsonDocument doc = QJsonDocument::fromJson(line.toUtf8());
    if (doc.isNull()) return;
    QJsonObject obj = doc.object();
    bool ok = obj.value("ok").toBool(false);
    if (!ok) {
        qWarning() << "Network: error response:" << obj.value("error").toString();
        return;
    }

    // Status response
    if (obj.contains("state")) {
        QString newState = obj.value("state").toString();
        QString newSsid  = obj.value("ssid").toString();
        QString newIp    = obj.value("ip").toString();
        if (newState != m_state || newSsid != m_ssid || newIp != m_ip) {
            m_state = newState;
            m_ssid  = newSsid;
            m_ip    = newIp;
            emit stateChanged();
        }
    }
    // Networks list
    if (obj.contains("networks")) {
        m_networks = obj.value("networks").toVariant().toList();
        emit networksChanged();
        if (m_scanning) {
            m_scanning = false;
            emit scanningChanged();
        }
    }
}

void NetworkManager::scan() {
    if (m_scanning) return;
    m_scanning = true;
    emit scanningChanged();
    sendCommand("{\"cmd\":\"scan\"}");
    // After scan, fetch list (the service waits 3s internally)
    QTimer::singleShot(4000, this, [this]() {
        sendCommand("{\"cmd\":\"list\"}");
    });
}

void NetworkManager::connectToNetwork(const QString &ssid, const QString &psk) {
    QString cmd = QString("{\"cmd\":\"connect\",\"ssid\":\"%1\",\"psk\":\"%2\"}")
                      .arg(ssid).arg(psk);
    sendCommand(cmd);
}

void NetworkManager::disconnect() {
    sendCommand("{\"cmd\":\"disconnect\"}");
}

void NetworkManager::refreshStatus() {
    sendCommand("{\"cmd\":\"status\"}");
}
