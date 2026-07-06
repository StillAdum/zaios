/*
 * BrowserManager.h — Wraps QtWebEngine for the in-OS browser.
 *
 * The actual webview is a QtWebEngineView in QML (see qml/pages/Browser.qml).
 * This class provides session helpers: bookmarks, history, URL normalization,
 * safe-search enforcement.
 */
#ifndef BROWSERMANAGER_H
#define BROWSERMANAGER_H

#include <QObject>
#include <QVariantList>

class BrowserManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString homeUrl READ homeUrl CONSTANT)
    Q_PROPERTY(QVariantList bookmarks READ bookmarks NOTIFY bookmarksChanged)
    Q_PROPERTY(QVariantList history READ history NOTIFY historyChanged)

public:
    explicit BrowserManager(QObject *parent = nullptr);

    QString homeUrl() const { return "https://duckduckgo.com/?kae=d&q=zaios"; }
    QVariantList bookmarks() const { return m_bookmarks; }
    QVariantList history() const { return m_history; }

    Q_INVOKABLE QString normalizeUrl(const QString &input);
    Q_INVOKABLE void addBookmark(const QString &url, const QString &title);
    Q_INVOKABLE void removeBookmark(const QString &url);
    Q_INVOKABLE void addToHistory(const QString &url, const QString &title);
    Q_INVOKABLE void clearHistory();

signals:
    void bookmarksChanged();
    void historyChanged();

private:
    QVariantList m_bookmarks;
    QVariantList m_history;
};

#endif
