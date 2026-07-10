/*
 * main.cpp — ZAIos Shell entry point.
 *
 * The shell is a Qt6/QML app that runs as the only client of Cage (Wayland
 * kiosk compositor). It is responsible for:
 *
 *   - First-time setup wizard (language, WiFi, Bluetooth, accounts)
 *   - Home screen with app tiles (Spotify, YouTube, Browser, Cast, Settings)
 *   - Per-app pages with their own UIs
 *   - Global input handling (D-pad nav, air mouse, keyboard)
 *   - Volume / power / notification overlays
 *   - Talking to background services via the C++ manager classes
 *
 * The C++ side registers manager objects as QML context properties so the
 * QML UI can call them directly.
 *
 * Author: ZAIos Project
 */
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QtQml>
#include <QSurfaceFormat>
#include <QFontDatabase>
#include <QIcon>
#include <QUrl>

#include "InputBridge.h"
#include "NetworkManager.h"
#include "BluetoothManager.h"
#include "CastManager.h"
#include "SpotifyManager.h"
#include "YouTubeManager.h"
#include "BrowserManager.h"
#include "SettingsManager.h"
#include "SetupWizard.h"
#include "AppManager.h"
#include "SystemService.h"
#include "PowerManager.h"
#include "NotificationManager.h"

int main(int argc, char **argv) {
    // ── Force Wayland (we run inside Cage) ─────────────────────────────────
    qputenv("QT_QPA_PLATFORM", "wayland");
    qputenv("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1");
    qputenv("QT_WAYLAND_SHELL_INTEGRATION", "xdg-shell");
    qputenv("QT_LOGGING_RULES", "qt.qpa.wayland=false");

    // ── Force OpenGL for animations ───────────────────────────────────────
    QSurfaceFormat fmt;
    fmt.setDepthBufferSize(24);
    fmt.setStencilBufferSize(8);
    fmt.setSamples(4);  // 4x MSAA for crispier edges
    fmt.setSwapBehavior(QSurfaceFormat::DoubleBuffer);
    fmt.setSwapInterval(1);  // vsync
    QSurfaceFormat::setDefaultFormat(fmt);

    // ── Qt app ────────────────────────────────────────────────────────────
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("zaios-shell");
    QGuiApplication::setApplicationVersion(ZAIOS_SHELL_VERSION);
    QGuiApplication::setOrganizationName("ZAIos");

    // Use Qt Quick Controls 2 with the "Material" style as a base — we
    // override almost everything with our glassmorphism theme.
    QQuickStyle::setStyle("Material");

    // Load custom fonts
    QFontDatabase::addApplicationFont(":/fonts/Inter-Regular.ttf");
    QFontDatabase::addApplicationFont(":/fonts/Inter-Medium.ttf");
    QFontDatabase::addApplicationFont(":/fonts/Inter-Bold.ttf");

    // ── Register C++ managers as QML types ────────────────────────────────
    qmlRegisterType<InputBridge>("ZAIos.Shell", 1, 0, "InputBridge");
    qmlRegisterType<NetworkManager>("ZAIos.Shell", 1, 0, "NetworkManager");
    qmlRegisterType<BluetoothManager>("ZAIos.Shell", 1, 0, "BluetoothManager");
    qmlRegisterType<CastManager>("ZAIos.Shell", 1, 0, "CastManager");
    qmlRegisterType<SpotifyManager>("ZAIos.Shell", 1, 0, "SpotifyManager");
    qmlRegisterType<YouTubeManager>("ZAIos.Shell", 1, 0, "YouTubeManager");
    qmlRegisterType<BrowserManager>("ZAIos.Shell", 1, 0, "BrowserManager");
    qmlRegisterType<SettingsManager>("ZAIos.Shell", 1, 0, "SettingsManager");
    qmlRegisterType<SetupWizard>("ZAIos.Shell", 1, 0, "SetupWizard");
    qmlRegisterType<AppManager>("ZAIos.Shell", 1, 0, "AppManager");
    qmlRegisterType<SystemService>("ZAIos.Shell", 1, 0, "SystemService");
    qmlRegisterType<PowerManager>("ZAIos.Shell", 1, 0, "PowerManager");
    qmlRegisterType<NotificationManager>("ZAIos.Shell", 1, 0, "NotificationManager");

    // ── Instantiate managers ──────────────────────────────────────────────
    SettingsManager      settings;
    InputBridge          input;
    NetworkManager       network;
    BluetoothManager     bluetooth;
    CastManager          cast;
    SpotifyManager       spotify;
    YouTubeManager       youtube;
    BrowserManager       browser;
    AppManager           apps;
    SystemService        sys;
    PowerManager         power;
    NotificationManager  notifications;

    // ── Wire cross-dependencies ───────────────────────────────────────────
    input.setSettings(&settings);
    notifications.setParent(&app);
    power.setSystem(&sys);

    // ── QML engine ────────────────────────────────────────────────────────
    QQmlApplicationEngine engine;

    engine.rootContext()->setContextProperty("Settings",     &settings);
    engine.rootContext()->setContextProperty("Input",        &input);
    engine.rootContext()->setContextProperty("Network",      &network);
    engine.rootContext()->setContextProperty("Bluetooth",    &bluetooth);
    engine.rootContext()->setContextProperty("Cast",         &cast);
    engine.rootContext()->setContextProperty("Spotify",      &spotify);
    engine.rootContext()->setContextProperty("YouTube",      &youtube);
    engine.rootContext()->setContextProperty("Browser",      &browser);
    engine.rootContext()->setContextProperty("Apps",         &apps);
    engine.rootContext()->setContextProperty("System",       &sys);
    engine.rootContext()->setContextProperty("Power",        &power);
    engine.rootContext()->setContextProperty("Notifications",&notifications);

    // Expose build version
    engine.rootContext()->setContextProperty("zaiosVersion", ZAIOS_SHELL_VERSION);

    // ── Load main QML ─────────────────────────────────────────────────────
#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
    engine.loadFromModule("ZAIos.Shell", "Main");
#else
    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/ZAIos/Shell/qml/main.qml")));
#endif

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "Failed to load ZAIos Shell QML";
        return 1;
    }

    // ── Start input bridge ────────────────────────────────────────────────
    input.start();

    // ── Decide whether to show first-time setup ───────────────────────────
    if (!settings.isSetupComplete()) {
        qDebug() << "First-time setup not complete — launching SetupWizard";
        // The QML UI watches Settings.setupComplete and shows wizard on false.
    }

    // ── Run ───────────────────────────────────────────────────────────────
    int ret = app.exec();

    // ── Cleanup ───────────────────────────────────────────────────────────
    input.stop();
    return ret;
}
