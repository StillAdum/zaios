/*
 * SettingsManager.cpp — stores all ZAIos shell settings in
 * /var/lib/zaios/settings.ini (QSettings backing store).
 *
 * Defaults chosen for a TV-OS feel: dark theme, English, auto-detect TZ,
 * volume 60, bluetooth on.
 */
#include "SettingsManager.h"
#include <QDir>

SettingsManager::SettingsManager(QObject *parent)
    : QObject(parent), m_s("ZAIos", "zaios-shell"), m_wifiConnected(false)
{
    // Make sure /var/lib/zaios exists
    QDir().mkpath("/var/lib/zaios");
    m_s.setPath(QSettings::IniFormat, QSettings::SystemScope, "/var/lib/zaios/zaios-shell.ini");
}

bool SettingsManager::isSetupComplete() const {
    return m_s.value("setupComplete", false).toBool();
}
void SettingsManager::setSetupComplete(bool v) {
    if (isSetupComplete() != v) {
        m_s.setValue("setupComplete", v);
        m_s.sync();
        emit setupCompleteChanged();
    }
}

QString SettingsManager::language() const   { return m_s.value("language", "en").toString(); }
void     SettingsManager::setLanguage(const QString &v) {
    if (language() != v) {
        m_s.setValue("language", v); m_s.sync();
        emit languageChanged();
    }
}

QString SettingsManager::timezone() const   { return m_s.value("timezone", "UTC").toString(); }
void     SettingsManager::setTimezone(const QString &v) {
    if (timezone() != v) {
        m_s.setValue("timezone", v); m_s.sync();
        emit timezoneChanged();
    }
}

QString SettingsManager::theme() const      { return m_s.value("theme", "glass-dark").toString(); }
void     SettingsManager::setTheme(const QString &v) {
    if (theme() != v) {
        m_s.setValue("theme", v); m_s.sync();
        emit themeChanged();
    }
}

int  SettingsManager::volume() const        { return m_s.value("volume", 60).toInt(); }
void SettingsManager::setVolume(int v) {
    v = qBound(0, v, 100);
    if (volume() != v) {
        m_s.setValue("volume", v); m_s.sync();
        emit volumeChanged();
    }
}

bool SettingsManager::muted() const         { return m_s.value("muted", false).toBool(); }
void SettingsManager::setMuted(bool v) {
    if (muted() != v) {
        m_s.setValue("muted", v); m_s.sync();
        emit mutedChanged();
    }
}

QString SettingsManager::wifiSsid() const     { return m_wifiSsid; }
bool    SettingsManager::wifiConnected() const { return m_wifiConnected; }
void    SettingsManager::setWifiState(const QString &ssid, bool connected) {
    if (m_wifiSsid != ssid || m_wifiConnected != connected) {
        m_wifiSsid = ssid;
        m_wifiConnected = connected;
        emit wifiChanged();
    }
}

QString SettingsManager::hostname() const   { return m_s.value("hostname", "zaios").toString(); }
void     SettingsManager::setHostname(const QString &v) {
    if (hostname() != v) {
        m_s.setValue("hostname", v); m_s.sync();
        emit hostnameChanged();
    }
}

bool SettingsManager::bluetoothEnabled() const { return m_s.value("bluetooth", true).toBool(); }
void  SettingsManager::setBluetoothEnabled(bool v) {
    if (bluetoothEnabled() != v) {
        m_s.setValue("bluetooth", v); m_s.sync();
        emit bluetoothEnabledChanged();
    }
}

QString SettingsManager::spotifyUser() const { return m_s.value("spotifyUser").toString(); }
void  SettingsManager::setSpotifyUser(const QString &v) {
    if (spotifyUser() != v) {
        m_s.setValue("spotifyUser", v); m_s.sync();
        emit spotifyUserChanged();
    }
}

QVariant SettingsManager::get(const QString &key, const QVariant &def) const {
    return m_s.value(key, def);
}
void SettingsManager::set(const QString &key, const QVariant &v) {
    m_s.setValue(key, v);
    m_s.sync();
}
