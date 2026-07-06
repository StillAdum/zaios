/*
 * SettingsManager.h — Persistent settings for ZAIos shell.
 */
#ifndef SETTINGSMANAGER_H
#define SETTINGSMANAGER_H

#include <QObject>
#include <QSettings>

class SettingsManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool   setupComplete READ isSetupComplete NOTIFY setupCompleteChanged)
    Q_PROPERTY(QString language     READ language       WRITE setLanguage     NOTIFY languageChanged)
    Q_PROPERTY(QString timezone     READ timezone       WRITE setTimezone     NOTIFY timezoneChanged)
    Q_PROPERTY(QString theme        READ theme          WRITE setTheme        NOTIFY themeChanged)
    Q_PROPERTY(int     volume       READ volume         WRITE setVolume       NOTIFY volumeChanged)
    Q_PROPERTY(bool    muted        READ muted          WRITE setMuted        NOTIFY mutedChanged)
    Q_PROPERTY(QString wifiSsid     READ wifiSsid       NOTIFY wifiChanged)
    Q_PROPERTY(bool    wifiConnected READ wifiConnected NOTIFY wifiChanged)
    Q_PROPERTY(QString hostname     READ hostname       WRITE setHostname     NOTIFY hostnameChanged)
    Q_PROPERTY(bool    bluetoothEnabled READ bluetoothEnabled WRITE setBluetoothEnabled NOTIFY bluetoothEnabledChanged)
    Q_PROPERTY(QString spotifyUser  READ spotifyUser    WRITE setSpotifyUser  NOTIFY spotifyUserChanged)

public:
    explicit SettingsManager(QObject *parent = nullptr);

    bool isSetupComplete() const;
    Q_INVOKABLE void setSetupComplete(bool v);

    QString language() const;     void setLanguage(const QString &);
    QString timezone() const;     void setTimezone(const QString &);
    QString theme() const;        void setTheme(const QString &);
    int volume() const;           void setVolume(int);
    bool muted() const;           void setMuted(bool);
    QString wifiSsid() const;
    bool wifiConnected() const;
    void setWifiState(const QString &ssid, bool connected);
    QString hostname() const;     void setHostname(const QString &);
    bool bluetoothEnabled() const; void setBluetoothEnabled(bool);
    QString spotifyUser() const;  void setSpotifyUser(const QString &);

    Q_INVOKABLE QVariant get(const QString &key, const QVariant &def = QVariant()) const;
    Q_INVOKABLE void set(const QString &key, const QVariant &v);

signals:
    void setupCompleteChanged();
    void languageChanged();
    void timezoneChanged();
    void themeChanged();
    void volumeChanged();
    void mutedChanged();
    void wifiChanged();
    void hostnameChanged();
    void bluetoothEnabledChanged();
    void spotifyUserChanged();

private:
    QSettings m_s;
    QString   m_wifiSsid;
    bool      m_wifiConnected;
};

#endif
