/*
 * AppManager.h — App launcher / installed apps registry.
 *
 * Lists installed apps (read from /usr/share/applications/*.desktop),
 * lets the QML UI launch them. Custom ZAIos apps (Spotify, YouTube,
 * Browser, Cast, Settings) are registered as built-ins.
 */
#ifndef APPMANAGER_H
#define APPMANAGER_H

#include <QObject>
#include <QVariantList>

class AppManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList apps READ apps NOTIFY appsChanged)

public:
    explicit AppManager(QObject *parent = nullptr);

    QVariantList apps() const { return m_apps; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void launch(const QString &appId);

signals:
    void appsChanged();
    void launchApp(const QString &appId);

private:
    QVariantList m_apps;
    void loadBuiltins();
    void loadDesktopFiles();
};

#endif
