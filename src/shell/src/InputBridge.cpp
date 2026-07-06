/*
 * InputBridge.cpp — Implementation of the ZAIos input bridge.
 *
 * Connects to /run/zaios/input.sock (served by zaios-input service).
 *
 * Reads JSON-line events like:
 *   {"type":"key","key":"Up","state":"pressed","dev":"..."}
 *   {"type":"relx","value":-3,"dev":"..."}
 *   {"type":"rely","value":2,"dev":"..."}
 *   {"type":"wheel","value":-1,"dev":"..."}
 *   {"type":"abs","axis":0,"value":1234,"dev":"..."}
 *
 * Translates them into Qt-friendly signals for QML.
 */
#include "InputBridge.h"
#include "SettingsManager.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QSocketNotifier>
#include <QFile>
#include <QDir>
#include <QCursor>
#include <QGuiApplication>
#include <QScreen>
#include <QQuickWindow>
#include <QDebug>

#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

#define SOCK_PATH "/run/zaios/input.sock"

InputBridge::InputBridge(QObject *parent)
    : QObject(parent), m_fd(-1), m_notifier(nullptr), m_connected(false),
      m_cursor(960, 540), m_cursorVisible(false), m_inputMode("all"),
      m_settings(nullptr)
{
    m_reconnectTimer.setInterval(2000);
    m_reconnectTimer.setSingleShot(false);
    connect(&m_reconnectTimer, &QTimer::timeout, this, &InputBridge::reconnect);

    m_cursorHideTimer.setInterval(3000);
    m_cursorHideTimer.setSingleShot(true);
    connect(&m_cursorHideTimer, &QTimer::timeout, this, [this]() {
        if (m_inputMode == "pointer") {
            showCursor(false);
        }
    });
}

InputBridge::~InputBridge() { stop(); }

bool InputBridge::start() {
    if (!connectToService()) {
        qDebug() << "InputBridge: service not ready, will retry";
        m_reconnectTimer.start();
    }
    return true;
}

void InputBridge::stop() {
    m_reconnectTimer.stop();
    if (m_notifier) { delete m_notifier; m_notifier = nullptr; }
    if (m_fd >= 0) { ::close(m_fd); m_fd = -1; }
    m_connected = false;
    emit connectedChanged();
}

bool InputBridge::connectToService() {
    m_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (m_fd < 0) return false;

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCK_PATH, sizeof(addr.sun_path) - 1);

    if (::connect(m_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        ::close(m_fd);
        m_fd = -1;
        return false;
    }

    // Make non-blocking
    int flags = fcntl(m_fd, F_GETFL, 0);
    fcntl(m_fd, F_SETFL, flags | O_NONBLOCK);

    m_notifier = new QSocketNotifier(m_fd, QSocketNotifier::Read, this);
    connect(m_notifier, &QSocketNotifier::activated, this, &InputBridge::onSocketReady);

    m_connected = true;
    emit connectedChanged();
    qDebug() << "InputBridge: connected to" << SOCK_PATH;
    return true;
}

void InputBridge::reconnect() {
    if (m_connected) return;
    qDebug() << "InputBridge: attempting reconnect...";
    if (m_notifier) { delete m_notifier; m_notifier = nullptr; }
    if (m_fd >= 0) { ::close(m_fd); m_fd = -1; }
    connectToService();
}

void InputBridge::onSocketReady() {
    char buf[4096];
    ssize_t n;
    while ((n = read(m_fd, buf, sizeof(buf))) > 0) {
        m_buffer.append(buf, n);
    }
    if (n == 0 || (n < 0 && errno != EAGAIN && errno != EWOULDBLOCK)) {
        qDebug() << "InputBridge: socket closed, will reconnect";
        m_connected = false;
        emit connectedChanged();
        if (m_notifier) { delete m_notifier; m_notifier = nullptr; }
        if (m_fd >= 0) { ::close(m_fd); m_fd = -1; }
        return;
    }

    // Process complete lines
    int idx;
    while ((idx = m_buffer.indexOf('\n')) >= 0) {
        QByteArray line = m_buffer.left(idx);
        m_buffer = m_buffer.mid(idx + 1);
        parseLine(QString::fromUtf8(line));
    }
}

void InputBridge::parseLine(const QString &line) {
    QJsonDocument doc = QJsonDocument::fromJson(line.toUtf8());
    if (doc.isNull()) return;
    QJsonObject obj = doc.object();

    QString type = obj.value("type").toString();
    QString dev  = obj.value("dev").toString();

    if (type == "key") {
        QString key = obj.value("key").toString();
        QString state = obj.value("state").toString();
        m_lastKey = key;
        emit lastKeyChanged();
        routeKey(key, state);
    } else if (type == "relx") {
        if (m_inputMode == "all" || m_inputMode == "pointer") {
            int dx = obj.value("value").toInt();
            moveCursor(dx, 0);
        }
    } else if (type == "rely") {
        if (m_inputMode == "all" || m_inputMode == "pointer") {
            int dy = obj.value("value").toInt();
            moveCursor(0, dy);
        }
    } else if (type == "wheel") {
        // Vertical scroll → emulate up/down nav
        int v = obj.value("value").toInt();
        if (v > 0) emit navEvent("down");
        else        emit navEvent("up");
    } else if (type == "abs") {
        // Absolute pointer (touch)
        int axis = obj.value("axis").toInt();
        int val  = obj.value("value").toInt();
        if (axis == 0) m_cursor.setX(val);
        else if (axis == 1) m_cursor.setY(val);
        emit cursorMoved();
        showCursor(true);
        m_cursorHideTimer.start();
    }
}

void InputBridge::routeKey(const QString &key, const QString &state) {
    if (state != "pressed" && state != "repeat") {
        // Released — most TV UIs ignore
        return;
    }

    // Map keys to nav / media / system events for the QML UI
    if (key == "Up" || key == "Down" || key == "Left" || key == "Right" ||
        key == "Ok" || key == "Back") {
        QString dir = key.toLower();
        if (dir == "ok") dir = "ok";
        emit navEvent(dir);
    } else if (key == "Home") {
        emit systemEvent("home");
    } else if (key == "Menu") {
        emit systemEvent("menu");
    } else if (key == "Power") {
        emit systemEvent("power");
    } else if (key == "VolumeUp") {
        emit systemEvent("volumeUp");
    } else if (key == "VolumeDown") {
        emit systemEvent("volumeDown");
    } else if (key == "Mute") {
        emit systemEvent("mute");
    } else if (key == "Play") {
        emit mediaEvent("play");
    } else if (key == "Pause") {
        emit mediaEvent("pause");
    } else if (key == "Stop") {
        emit mediaEvent("stop");
    } else if (key == "Next") {
        emit mediaEvent("next");
    } else if (key == "Previous") {
        emit mediaEvent("prev");
    } else if (key == "Rewind") {
        emit mediaEvent("rewind");
    } else if (key == "FastForward") {
        emit mediaEvent("fastforward");
    } else if (key == "Search") {
        emit systemEvent("search");
    } else if (key == "Red" || key == "Green" || key == "Yellow" || key == "Blue") {
        emit systemEvent(key.toLower());
    } else if (key.length() == 1 && key[0].isDigit()) {
        emit numberEvent(key.toInt());
    } else {
        // Pass-through as generic key event
        emit keyEvent(key, state);
    }
}

void InputBridge::sendVirtualKey(const QString &key) {
    routeKey(key, "pressed");
}

void InputBridge::showCursor(bool visible) {
    if (m_cursorVisible != visible) {
        m_cursorVisible = visible;
        emit cursorVisibleChanged();
    }
    if (visible) {
        m_cursorHideTimer.start();
    }
}

void InputBridge::moveCursor(int dx, int dy) {
    if (!dx && !dy) return;

    QScreen *screen = QGuiApplication::primaryScreen();
    QRect geo = screen->geometry();

    int nx = m_cursor.x() + dx * 3;  // sensitivity multiplier
    int ny = m_cursor.y() + dy * 3;
    nx = qBound(0, nx, geo.width() - 1);
    ny = qBound(0, ny, geo.height() - 1);

    if (nx != m_cursor.x() || ny != m_cursor.y()) {
        m_cursor.setX(nx);
        m_cursor.setY(ny);
        emit cursorMoved();
        showCursor(true);
    }
}

void InputBridge::click() {
    emit navEvent("ok");
}

void InputBridge::onCursorTimeout() {
    showCursor(false);
}
