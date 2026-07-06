#include "AppManager.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QProcess>
#include <QDebug>

AppManager::AppManager(QObject *parent) : QObject(parent) {
    loadBuiltins();
    loadDesktopFiles();
}

void AppManager::loadBuiltins() {
    QVariantList builtins = {
        QVariantMap{{"id","spotify"},   {"name","Spotify"},    {"icon","spotify"},   {"category","media"},   {"builtin",true}},
        QVariantMap{{"id","youtube"},   {"name","YouTube"},    {"icon","youtube"},   {"category","media"},   {"builtin",true}},
        QVariantMap{{"id","browser"},   {"name","Browser"},    {"icon","browser"},   {"category","internet"},{"builtin",true}},
        QVariantMap{{"id","cast"},      {"name","Cast"},       {"icon","cast"},      {"category","system"},  {"builtin",true}},
        QVariantMap{{"id","settings"},  {"name","Settings"},   {"icon","settings"},  {"category","system"},  {"builtin",true}},
        QVariantMap{{"id","apps"},      {"name","All Apps"},   {"icon","apps"},      {"category","system"},  {"builtin",true}},
    };
    m_apps = builtins;
    emit appsChanged();
}

void AppManager::loadDesktopFiles() {
    QDir dir("/usr/share/applications");
    if (!dir.exists()) return;
    for (const QFileInfo &fi : dir.entryInfoList(QStringList() << "*.desktop")) {
        QFile f(fi.filePath());
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) continue;
        QTextStream in(&f);
        QVariantMap app;
        app["id"] = fi.baseName();
        app["builtin"] = false;
        while (!in.atEnd()) {
            QString line = in.readLine().trimmed();
            if (line.startsWith("Name="))     app["name"] = line.mid(5);
            else if (line.startsWith("Icon="))  app["icon"] = line.mid(5);
            else if (line.startsWith("Exec="))  app["exec"] = line.mid(5);
            else if (line.startsWith("Categories=")) app["category"] = line.mid(11).split(";").first();
        }
        if (app.contains("name") && app.contains("exec")) {
            m_apps << app;
        }
    }
    emit appsChanged();
}

void AppManager::refresh() {
    m_apps.clear();
    loadBuiltins();
    loadDesktopFiles();
}

void AppManager::launch(const QString &appId) {
    qDebug() << "AppManager: launching" << appId;
    // Builtin apps are handled by the QML UI (it switches pages).
    for (const QVariant &v : m_apps) {
        QVariantMap m = v.toMap();
        if (m.value("id").toString() == appId) {
            if (m.value("builtin").toBool()) {
                emit launchApp(appId);
            } else if (m.contains("exec")) {
                QProcess::startDetached(m.value("exec").toString().split(" ").first());
            }
            return;
        }
    }
}
