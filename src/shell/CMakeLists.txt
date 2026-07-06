# =============================================================================
# ZAIos Shell — CMakeLists.txt
#
# Builds the zaios-shell binary: a Qt6/QML TV desktop that runs as the sole
# client of Cage (Wayland kiosk compositor).
#
# Dependencies (Qt6 modules):
#   - Core / Gui / Quick / Qml / QuickControls2   (UI)
#   - WaylandClient                                (run as Wayland client)
#   - WebEngineQuick                               (Chromium browser embed)
#   - Multimedia                                   (audio playback fallback)
#   - Network                                      (HTTP for APIs)
#   - DBus                                         (talk to BlueZ, etc.)
#   - Bluetooth                                    (QtBluetooth)
#   - ShaderTools                                  (glass blur effect)
# =============================================================================
cmake_minimum_required(VERSION 3.20)

project(zaios-shell
    VERSION 1.0.0
    DESCRIPTION "ZAIos TV Shell"
    LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# ── Find Qt6 ─────────────────────────────────────────────────────────────────
find_package(Qt6 6.5 REQUIRED COMPONENTS
    Core
    Gui
    Quick
    Qml
    QuickControls2
    WaylandClient
    WebEngineQuick
    Multimedia
    Network
    DBus
    Bluetooth
    ShaderTools
    Svg
)

qt_standard_project_setup(REQUIRES 6.5)

# ── Sources ──────────────────────────────────────────────────────────────────
set(ZAIOS_SOURCES
    src/main.cpp
    src/InputBridge.cpp           src/InputBridge.h
    src/NetworkManager.cpp        src/NetworkManager.h
    src/BluetoothManager.cpp      src/BluetoothManager.h
    src/CastManager.cpp           src/CastManager.h
    src/SpotifyManager.cpp        src/SpotifyManager.h
    src/YouTubeManager.cpp        src/YouTubeManager.h
    src/BrowserManager.cpp        src/BrowserManager.h
    src/SettingsManager.cpp       src/SettingsManager.h
    src/SetupWizard.cpp           src/SetupWizard.h
    src/AppManager.cpp            src/AppManager.h
    src/SystemService.cpp         src/SystemService.h
    src/PowerManager.cpp          src/PowerManager.h
    src/NotificationManager.cpp   src/NotificationManager.h
)

# ── QML module ───────────────────────────────────────────────────────────────
qt_add_qml_module(zaios-shell
    URI ZAIos.Shell
    VERSION 1.0
    QML_FILES
        qml/main.qml
        qml/components/Background.qml
        qml/components/TopBar.qml
        qml/components/GlassCard.qml
        qml/components/FocusButton.qml
        qml/components/AppTile.qml
        qml/components/VolumeOverlay.qml
        qml/components/PowerMenu.qml
        qml/components/Toast.qml
        qml/components/NetworkBadge.qml
        qml/components/BatteryBadge.qml
        qml/components/ClockWidget.qml
        qml/components/SearchBar.qml
        qml/styles/Theme.qml
        qml/styles/Glassmorphism.qml
        qml/pages/Home.qml
        qml/pages/SetupWizard.qml
        qml/pages/Spotify.qml
        qml/pages/YouTube.qml
        qml/pages/Browser.qml
        qml/pages/Cast.qml
        qml/pages/Settings.qml
        qml/pages/Network.qml
        qml/pages/Bluetooth.qml
        qml/pages/About.qml
        qml/pages/Apps.qml
    RESOURCES
        resources/icons/zaios-logo.svg
        resources/icons/cursor.svg
)

# ── Executable ───────────────────────────────────────────────────────────────
add_executable(zaios-shell ${ZAIOS_SOURCES})

target_link_libraries(zaios-shell PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::Qml
    Qt6::QuickControls2
    Qt6::WaylandClient
    Qt6::WebEngineQuick
    Qt6::Multimedia
    Qt6::Network
    Qt6::DBus
    Qt6::Bluetooth
    Qt6::ShaderTools
    Qt6::Svg
)

target_compile_definitions(zaios-shell PRIVATE
    ZAIOS_SHELL_VERSION="${PROJECT_VERSION}"
    QT_DEPRECATED_WARNINGS
)

# Install
install(TARGETS zaios-shell DESTINATION /usr/bin)
install(DIRECTORY qml/ DESTINATION /usr/share/zaios/qml)
install(DIRECTORY resources/ DESTINATION /usr/share/zaios)
