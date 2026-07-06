/*
 * SpotifyManager.cpp — Implementation.
 */
#include "SpotifyManager.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QTimer>
#include <QDebug>

#define SOCK_PATH "/run/zaios/spotify.sock"

SpotifyManager::SpotifyManager(QObject *parent)
    : QObject(parent), m_sock(new QLocalSocket(this)),
      m_playing(false), m_pos(0), m_duration(0)
{
    connect(m_sock, &QLocalSocket::readyRead, this, &SpotifyManager::onReadyRead);
    connect(m_sock, &QLocalSocket::disconnected, this, [this]() {
        QTimer::singleShot(2000, this, &SpotifyManager::tryConnect);
    });

    QTimer::singleShot(1500, this, &SpotifyManager::tryConnect);

    // Periodic status poll for playback position
    QTimer *t = new QTimer(this);
    t->setInterval(2000);
    connect(t, &QTimer::timeout, this, &SpotifyManager::refreshStatus);
    t->start();
}

void SpotifyManager::tryConnect() {
    if (m_sock->state() == QLocalSocket::ConnectedState) return;
    m_sock->connectToServer(SOCK_PATH);
}

void SpotifyManager::sendCommand(const QString &cmd) {
    if (m_sock->state() != QLocalSocket::ConnectedState) return;
    m_sock->write((cmd + "\n").toUtf8());
    m_sock->flush();
}

void SpotifyManager::onReadyRead() {
    m_buffer.append(m_sock->readAll());
    int idx;
    while ((idx = m_buffer.indexOf('\n')) >= 0) {
        QByteArray line = m_buffer.left(idx);
        m_buffer = m_buffer.mid(idx + 1);
        handleResponse(QString::fromUtf8(line));
    }
}

void SpotifyManager::handleResponse(const QString &line) {
    QJsonDocument doc = QJsonDocument::fromJson(line.toUtf8());
    if (doc.isNull()) return;
    QJsonObject obj = doc.object();
    bool ok = obj.value("ok").toBool();
    if (!ok) {
        QString err = obj.value("error").toString();
        qWarning() << "Spotify error:" << err;
        emit error(err);
        return;
    }

    // Search results
    if (obj.contains("results")) {
        m_results = obj.value("results").toVariant().toList();
        emit resultsChanged();
    }

    // Status
    if (obj.contains("playing")) {
        bool newPlaying  = obj.value("playing").toBool();
        QString newTitle = obj.value("title").toString();
        int newPos       = obj.value("pos").toInt();
        int newDur       = obj.value("duration").toInt();
        QString newBack  = obj.value("backend").toString();

        if (newPlaying != m_playing || newTitle != m_title ||
            newPos != m_pos || newDur != m_duration || newBack != m_backend) {
            m_playing  = newPlaying;
            m_title    = newTitle;
            m_pos      = newPos;
            m_duration = newDur;
            m_backend  = newBack;
            emit statusChanged();
        }
    }
}

void SpotifyManager::search(const QString &query) {
    QString cmd = QString("{\"cmd\":\"search\",\"q\":\"%1\"}").arg(query);
    sendCommand(cmd);
}

void SpotifyManager::play(const QString &trackId, const QString &title,
                          const QString &artist, int duration) {
    QString cmd = QString("{\"cmd\":\"play\",\"track_id\":\"%1\",\"title\":\"%2\","
                          "\"artist\":\"%3\",\"duration\":%4}")
                      .arg(trackId, title, artist).arg(duration);
    sendCommand(cmd);
}

void SpotifyManager::pause()    { sendCommand("{\"cmd\":\"pause\"}"); }
void SpotifyManager::resume()   { sendCommand("{\"cmd\":\"resume\"}"); }
void SpotifyManager::stop()     { sendCommand("{\"cmd\":\"stop\"}"); }
void SpotifyManager::refreshStatus() { sendCommand("{\"cmd\":\"status\"}"); }

void SpotifyManager::seek(int seconds) {
    sendCommand(QString("{\"cmd\":\"seek\",\"pos\":%1}").arg(seconds));
}

void SpotifyManager::loginLibrespot(const QString &user, const QString &pass) {
    QString cmd = QString("{\"cmd\":\"librespot_login\",\"user\":\"%1\",\"pass\":\"%2\"}")
                      .arg(user, pass);
    sendCommand(cmd);
}
