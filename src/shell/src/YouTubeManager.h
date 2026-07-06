/*
 * YouTubeManager.h — Talk to yt-dlp+mpv for YouTube playback.
 *
 * Spawns mpv in the background with a Unix socket for IPC, exposes
 * search/play/control to QML. Uses Invidious API for search (no API key
 * needed).
 */
#ifndef YOUTUBEMANAGER_H
#define YOUTUBEMANAGER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QProcess>
#include <QVariantList>

class YouTubeManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool playing       READ playing       NOTIFY statusChanged)
    Q_PROPERTY(QString title      READ title         NOTIFY statusChanged)
    Q_PROPERTY(QString channel    READ channel       NOTIFY statusChanged)
    Q_PROPERTY(int pos            READ pos           NOTIFY statusChanged)
    Q_PROPERTY(int duration       READ duration      NOTIFY statusChanged)
    Q_PROPERTY(QVariantList results READ results     NOTIFY resultsChanged)

public:
    explicit YouTubeManager(QObject *parent = nullptr);

    bool playing() const { return m_playing; }
    QString title() const { return m_title; }
    QString channel() const { return m_channel; }
    int pos() const { return m_pos; }
    int duration() const { return m_duration; }
    QVariantList results() const { return m_results; }

    Q_INVOKABLE void search(const QString &query);
    Q_INVOKABLE void play(const QString &videoId, const QString &title);
    Q_INVOKABLE void pause();
    Q_INVOKABLE void resume();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void seek(int seconds);
    Q_INVOKABLE void setVolume(int vol);

signals:
    void statusChanged();
    void resultsChanged();
    void error(const QString &msg);

private slots:
    void onSearchReply();
    void pollMpvStatus();

private:
    void startMpv();
    void mpvCommand(const QString &cmd);

    QNetworkAccessManager *m_nam;
    QProcess              *m_mpv;
    QString                m_mpvSocket;
    bool                   m_playing;
    QString                m_title;
    QString                m_channel;
    int                    m_pos;
    int                    m_duration;
    QVariantList           m_results;
};

#endif
