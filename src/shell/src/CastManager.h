/*
 * CastManager.h — Miracast (Wi-Fi Display) sink control via zaios-cast.
 */
#ifndef CASTMANAGER_H
#define CASTMANAGER_H

#include <QObject>
#include <QLocalSocket>
#include <QVariantList>

class CastManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString state READ state NOTIFY stateChanged)
    Q_PROPERTY(QVariantList peers READ peers NOTIFY peersChanged)

public:
    explicit CastManager(QObject *parent = nullptr);

    QString state() const { return m_state; }
    QVariantList peers() const { return m_peers; }

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void refreshStatus();
    Q_INVOKABLE void listPeers();
    Q_INVOKABLE void accept(const QString &peer);
    Q_INVOKABLE void reject(const QString &peer);

signals:
    void stateChanged();
    void peersChanged();
    void error(const QString &msg);

private slots:
    void onReadyRead();
    void tryConnect();

private:
    void sendCommand(const QString &cmd);
    void handleResponse(const QString &line);

    QLocalSocket *m_sock;
    QByteArray m_buffer;
    QString m_state;
    QVariantList m_peers;
};

#endif
