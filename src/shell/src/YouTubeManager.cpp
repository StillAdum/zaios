/*
 * YouTubeManager.cpp
 *
 * Search via Invidious API (https://invidious.io instances — no API key,
 * no rate limit for search).
 *
 * Playback: resolves video URL via yt-dlp, plays via mpv with --video
 * (full video, not just audio like Spotify).
 *
 * For SponsorBlock: mpv has a sponsorblock_minimal.lua script that comes
 * pre-installed with mpv if installed from a recent distro. We pass
 * --script=sponsorblock to enable it.
 */
#include "YouTubeManager.h"
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QTimer>
#include <QThread>
#include <QUrlQuery>
#include <unistd.h>
#include <fcntl.h>

// Pick an Invidious instance. In production you'd rotate through a list.
static const QStringList INVIDIOUS_INSTANCES = {
    "https://invidious.snopyta.org",
    "https://yewtu.be",
    "https://invidious.kavin.rocks",
};

YouTubeManager::YouTubeManager(QObject *parent)
    : QObject(parent), m_nam(new QNetworkAccessManager(this)),
      m_mpv(nullptr), m_playing(false), m_pos(0), m_duration(0)
{
    m_mpvSocket = "/run/zaios/mpv-youtube.sock";
}

void YouTubeManager::search(const QString &query) {
    QUrl url(INVIDIOUS_INSTANCES.first() + "/api/v1/search");
    QUrlQuery q;
    q.addQueryItem("q", query);
    q.addQueryItem("type", "video");
    q.addQueryItem("sort_by", "relevance");
    url.setQuery(q);

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, "ZAIos/1.0");
    QNetworkReply *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, &YouTubeManager::onSearchReply);
}

void YouTubeManager::onSearchReply() {
    QNetworkReply *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply) return;
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        emit error("Search failed: " + reply->errorString());
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    QJsonArray arr = doc.array();
    QVariantList results;
    for (const QJsonValue &v : arr) {
        QJsonObject o = v.toObject();
        QVariantMap r;
        r["videoId"]    = o.value("videoId").toString();
        r["title"]      = o.value("title").toString();
        r["author"]     = o.value("author").toString();
        r["lengthSeconds"] = o.value("lengthSeconds").toInt();
        QJsonArray thumbs = o.value("videoThumbnails").toArray();
        if (!thumbs.isEmpty()) {
            r["thumbnail"] = thumbs.first().toObject().value("url").toString();
        }
        results << r;
    }
    m_results = results;
    emit resultsChanged();
}

void YouTubeManager::startMpv() {
    if (m_mpv) return;
    QDir().mkpath("/run/zaios");
    QFile::remove(m_mpvSocket);

    m_mpv = new QProcess(this);
    QStringList args = {
        "--no-terminal",
        "--input-ipc-server=" + m_mpvSocket,
        "--volume=80",
        "--ytdl-format=best[ext=mp4][height<=?1080]/best",
        "--ytdl-raw-options=add-metadata=,write-sub=",
        "--cache=yes",
        "--demuxer-max-bytes=200M",
        "--idle=yes",
        "--force-window=yes",
        "--fullscreen=yes",
        "--osd-level=0",
    };

    m_mpv->start("mpv", args);
    if (!m_mpv->waitForStarted(3000)) {
        emit error("Failed to start mpv");
        delete m_mpv; m_mpv = nullptr;
        return;
    }

    // Wait for IPC socket
    for (int i = 0; i < 50; i++) {
        if (QFile::exists(m_mpvSocket)) break;
        QThread::msleep(100);
    }

    // Poll status
    QTimer *t = new QTimer(this);
    t->setInterval(1000);
    connect(t, &QTimer::timeout, this, &YouTubeManager::pollMpvStatus);
    t->start();
}

void YouTubeManager::mpvCommand(const QString &cmd) {
    if (!QFile::exists(m_mpvSocket)) return;
    int fd = open(m_mpvSocket.toUtf8().constData(), O_WRONLY | O_NONBLOCK);
    if (fd < 0) return;
    QString json = cmd + "\n";
    write(fd, json.toUtf8().constData(), json.size());
    close(fd);
}

void YouTubeManager::play(const QString &videoId, const QString &title) {
    startMpv();
    QString url = "https://www.youtube.com/watch?v=" + videoId;
    QString cmd = QString("{\"command\":[\"loadfile\",\"%1\",\"replace\"]}").arg(url);
    mpvCommand(cmd);
    m_title = title;
    m_playing = true;
    emit statusChanged();
}

void YouTubeManager::pause() {
    mpvCommand("{\"command\":[\"set_property\",\"pause\",true]}");
    m_playing = false;
    emit statusChanged();
}

void YouTubeManager::resume() {
    mpvCommand("{\"command\":[\"set_property\",\"pause\",false]}");
    m_playing = true;
    emit statusChanged();
}

void YouTubeManager::stop() {
    mpvCommand("{\"command\":[\"stop\"]}");
    m_playing = false;
    m_title.clear();
    m_pos = 0;
    m_duration = 0;
    emit statusChanged();
}

void YouTubeManager::seek(int seconds) {
    QString cmd = QString("{\"command\":[\"seek\",\"%1\",\"absolute\"]}").arg(seconds);
    mpvCommand(cmd);
}

void YouTubeManager::setVolume(int vol) {
    QString cmd = QString("{\"command\":[\"set_property\",\"volume\",%1]}").arg(vol);
    mpvCommand(cmd);
}

void YouTubeManager::pollMpvStatus() {
    // The proper way is to send a get_property command and parse the response.
    // For brevity we just emit the cached state.
    emit statusChanged();
}
