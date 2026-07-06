#include "BrowserManager.h"
#include <QSettings>
#include <QUrl>
#include <QDateTime>

BrowserManager::BrowserManager(QObject *parent) : QObject(parent) {
    QSettings s("ZAIos", "browser");
    s.beginGroup("bookmarks");
    for (const QString &k : s.childKeys()) {
        QVariantMap b;
        b["url"] = k;
        b["title"] = s.value(k).toString();
        m_bookmarks << b;
    }
    s.endGroup();
    s.beginGroup("history");
    for (const QString &k : s.childKeys()) {
        QVariantMap h;
        h["url"] = k;
        h["title"] = s.value(k).toString();
        m_history << h;
    }
}

QString BrowserManager::normalizeUrl(const QString &input) {
    QString s = input.trimmed();
    if (s.isEmpty()) return QString();

    // If it looks like a URL (has a dot, no spaces), add http://
    if (!s.contains(' ') && s.contains('.') && !s.startsWith("http")) {
        return "https://" + s;
    }
    // Otherwise treat as a search query
    return "https://duckduckgo.com/?q=" + QUrl::toPercentEncoding(s);
}

void BrowserManager::addBookmark(const QString &url, const QString &title) {
    QVariantMap b;
    b["url"] = url;
    b["title"] = title;
    m_bookmarks << b;
    QSettings s("ZAIos", "browser");
    s.setValue("bookmarks/" + url, title);
    emit bookmarksChanged();
}

void BrowserManager::removeBookmark(const QString &url) {
    QVariantList nl;
    for (const QVariant &v : m_bookmarks) {
        if (v.toMap().value("url").toString() != url) nl << v;
    }
    m_bookmarks = nl;
    QSettings s("ZAIos", "browser");
    s.remove("bookmarks/" + url);
    emit bookmarksChanged();
}

void BrowserManager::addToHistory(const QString &url, const QString &title) {
    QVariantMap h;
    h["url"] = url;
    h["title"] = title;
    h["time"] = QDateTime::currentDateTime().toMSecsSinceEpoch();
    m_history.prepend(h);
    if (m_history.size() > 200) m_history = m_history.mid(0, 200);
    QSettings s("ZAIos", "browser");
    s.setValue("history/" + url, title);
    emit historyChanged();
}

void BrowserManager::clearHistory() {
    m_history.clear();
    QSettings s("ZAIos", "browser");
    s.remove("history");
    emit historyChanged();
}
