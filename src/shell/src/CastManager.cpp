#include "CastManager.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QTimer>
#include <QDebug>

#define SOCK_PATH "/run/zaios/cast.sock"

CastManager::CastManager(QObject *parent)
    : QObject(parent), m_sock(new QLocalSocket(this)), m_state("stopped")
{
    connect(m_sock, &QLocalSocket::readyRead, this, &CastManager::onReadyRead);
    connect(m_sock, &QLocalSocket::disconnected, this, [this]() {
        QTimer::singleShot(2000, this, &CastManager::tryConnect);
    });
    QTimer::singleShot(1500, this, &CastManager::tryConnect);
}

void CastManager::tryConnect() {
    if (m_sock->state() == QLocalSocket::ConnectedState) return;
    m_sock->connectToServer(SOCK_PATH);
}

void CastManager::sendCommand(const QString &cmd) {
    if (m_sock->state() != QLocalSocket::ConnectedState) return;
    m_sock->write((cmd + "\n").toUtf8());
    m_sock->flush();
}

void CastManager::onReadyRead() {
    m_buffer.append(m_sock->readAll());
    int idx;
    while ((idx = m_buffer.indexOf('\n')) >= 0) {
        QByteArray line = m_buffer.left(idx);
        m_buffer = m_buffer.mid(idx + 1);
        handleResponse(QString::fromUtf8(line));
    }
}

void CastManager::handleResponse(const QString &line) {
    QJsonDocument doc = QJsonDocument::fromJson(line.toUtf8());
    if (doc.isNull()) return;
    QJsonObject obj = doc.object();
    if (!obj.value("ok").toBool()) {
        emit error(obj.value("error").toString());
        return;
    }
    if (obj.contains("state")) {
        QString s = obj.value("state").toString();
        if (s != m_state) { m_state = s; emit stateChanged(); }
    }
    if (obj.contains("peers")) {
        m_peers = obj.value("peers").toVariant().toList();
        emit peersChanged();
    }
}

void CastManager::start()         { sendCommand("{\"cmd\":\"start\"}"); }
void CastManager::stop()          { sendCommand("{\"cmd\":\"stop\"}"); }
void CastManager::refreshStatus() { sendCommand("{\"cmd\":\"status\"}"); }
void CastManager::listPeers()     { sendCommand("{\"cmd\":\"list_peers\"}"); }
void CastManager::accept(const QString &peer) {
    sendCommand(QString("{\"cmd\":\"accept\",\"peer\":\"%1\"}").arg(peer));
}
void CastManager::reject(const QString &peer) {
    sendCommand(QString("{\"cmd\":\"reject\",\"peer\":\"%1\"}").arg(peer));
}
