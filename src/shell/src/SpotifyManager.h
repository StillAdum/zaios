/*
 * SpotifyManager.h — Talk to zaios-spotify service.
 *
 * Exposes search / play / pause / status to QML. The backend service
 * handles Spotube-style (YouTube-backed) and librespot backends.
 */
#ifndef SPOTIFYMANAGER_H
#define SPOTIFYMANAGER_H

#include <QObject>
#include <QLocalSocket>
#include <QVariantList>

class SpotifyManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool        playing   READ playing   NOTIFY statusChanged)
    Q_PROPERTY(QString     title     READ title     NOTIFY statusChanged)
    Q_PROPERTY(int         pos       READ pos       NOTIFY statusChanged)
    Q_PROPERTY(int         duration  READ duration  NOTIFY statusChanged)
    Q_PROPERTY(QString     backend   READ backend   NOTIFY statusChanged)
    Q_PROPERTY(QVariantList results  READ results   NOTIFY resultsChanged)

public:
    explicit SpotifyManager(QObject *parent = nullptr);

    bool    playing() const  { return m_playing; }
    QString title() const    { return m_title; }
    int     pos() const      { return m_pos; }
    int     duration() const { return m_duration; }
    QString backend() const  { return m_backend; }
    QVariantList results() const { return m_results; }

    Q_INVOKABLE void search(const QString &query);
    Q_INVOKABLE void play(const QString &trackId, const QString &title,
                          const QString &artist, int duration);
    Q_INVOKABLE void pause();
    Q_INVOKABLE void resume();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void seek(int seconds);
    Q_INVOKABLE void refreshStatus();
    Q_INVOKABLE void loginLibrespot(const QString &user, const QString &pass);

signals:
    void statusChanged();
    void resultsChanged();
    void error(const QString &msg);

private slots:
    void onReadyRead();
    void tryConnect();

private:
    void sendCommand(const QString &cmd);
    void handleResponse(const QString &line);

    QLocalSocket *m_sock;
    QByteArray    m_buffer;
    bool          m_playing;
    QString       m_title;
    int           m_pos;
    int           m_duration;
    QString       m_backend;
    QVariantList  m_results;
};

#endif
