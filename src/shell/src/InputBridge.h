/*
 * InputBridge.h — Connects the zaios-input service (Unix socket) to Qt's
 * input event pipeline.
 *
 * Reads JSON events from /run/zaios/input.sock and translates them into:
 *   - Qt key events (for D-pad navigation + keyboard)
 *   - Qt mouse move/click events (for air mouse / gyro pointer)
 *   - Touch events (for touchscreens)
 *
 * The bridge is bidirectional: QML can also call sendVirtualKey() to
 * synthesize key presses (e.g. for app shortcuts).
 */
#ifndef INPUTBRIDGE_H
#define INPUTBRIDGE_H

#include <QObject>
#include <QSocketNotifier>
#include <QHash>
#include <QTimer>
#include <QPoint>

class SettingsManager;

class InputBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool   connected       READ connected       NOTIFY connectedChanged)
    Q_PROPERTY(int    cursorX         READ cursorX         NOTIFY cursorMoved)
    Q_PROPERTY(int    cursorY         READ cursorY         NOTIFY cursorMoved)
    Q_PROPERTY(bool   cursorVisible   READ cursorVisible   NOTIFY cursorVisibleChanged)
    Q_PROPERTY(QString lastKey        READ lastKey         NOTIFY lastKeyChanged)
    Q_PROPERTY(QString inputMode      READ inputMode       NOTIFY inputModeChanged)

public:
    explicit InputBridge(QObject *parent = nullptr);
    ~InputBridge();

    bool start();
    void stop();

    bool connected() const { return m_connected; }
    int  cursorX() const { return m_cursor.x(); }
    int  cursorY() const { return m_cursor.y(); }
    bool cursorVisible() const { return m_cursorVisible; }
    QString lastKey() const { return m_lastKey; }

    // "dpad", "pointer", "keyboard", "all"
    QString inputMode() const { return m_inputMode; }
    void setInputMode(const QString &mode) {
        if (m_inputMode != mode) {
            m_inputMode = mode;
            emit inputModeChanged();
        }
    }

    void setSettings(SettingsManager *s) { m_settings = s; }

    // QML-invokable
    Q_INVOKABLE void sendVirtualKey(const QString &key);
    Q_INVOKABLE void showCursor(bool visible);
    Q_INVOKABLE void moveCursor(int dx, int dy);
    Q_INVOKABLE void click();

signals:
    void connectedChanged();
    void cursorMoved();
    void cursorVisibleChanged();
    void lastKeyChanged();
    void inputModeChanged();

    // Emitted for the QML UI to react to key events
    void keyEvent(const QString &key, const QString &state);
    void navEvent(const QString &direction);  // "up","down","left","right","ok","back"
    void mediaEvent(const QString &action);   // "play","pause","stop","next","prev"
    void systemEvent(const QString &action);  // "home","menu","power","volumeUp","volumeDown","mute"
    void numberEvent(int digit);

private slots:
    void onSocketReady();
    void onCursorTimeout();
    void reconnect();

private:
    bool connectToService();
    void parseLine(const QString &line);
    void routeKey(const QString &key, const QString &state);

    int                  m_fd;
    QSocketNotifier     *m_notifier;
    QByteArray           m_buffer;
    bool                 m_connected;
    QTimer               m_reconnectTimer;
    QTimer               m_cursorHideTimer;
    QPoint               m_cursor;
    bool                 m_cursorVisible;
    QString              m_lastKey;
    QString              m_inputMode;
    SettingsManager     *m_settings;
};

#endif // INPUTBRIDGE_H
