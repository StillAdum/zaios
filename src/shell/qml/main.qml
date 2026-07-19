/*
 * main.qml — Root ZAIos Shell window.
 *
 * Responsibilities:
 *   - Show SetupWizard on first boot, Home afterwards
 *   - Global key event routing (D-pad, keyboard, air mouse)
 *   - Top bar (clock, network, bluetooth, volume)
 *   - Page navigation (Home, Spotify, YouTube, Browser, Cast, Settings)
 *   - Volume overlay (shown on volume key press)
 *   - Power menu overlay
 *   - Toast notification stack
 *
 * The whole shell runs full-screen via Cage (Wayland kiosk). No window
 * decorations, no title bar.
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import ZAIos.Shell
import "components"
import "pages"
import "styles"

ApplicationWindow {
    id: root
    visible: true
    width: Screen.width
    height: Screen.height
    visibility: Window.FullScreen
    color: "#050816"
    title: "ZAIos"

    // ── Global state ─────────────────────────────────────────────────────
    property string currentPage: Settings.setupComplete ? "home" : "setup"
    property string previousPage: "home"
    property bool   volumeOverlayVisible: false
    property bool   powerMenuVisible: false
    property bool   cursorMode: false

    // ── Background: animated gradient + noise ────────────────────────────
    Background {
        anchors.fill: parent
    }

    // ── Page stack ───────────────────────────────────────────────────────
    StackView {
        id: pageStack
        anchors.fill: parent
        initialItem: Settings.setupComplete ? homePage : setupPage

        // Custom push animation — slide + fade with slight scale
        pushEnter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "x"; from: pageStack.width; to: 0; duration: 350; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 350; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.96; to: 1.0; duration: 350; easing.type: Easing.OutCubic }
            }
        }
        pushExit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "x"; from: 0; to: -pageStack.width * 0.3; duration: 350; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; from: 1; to: 0.4; duration: 350; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 1.0; to: 0.98; duration: 350; easing.type: Easing.OutCubic }
            }
        }
        popEnter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "x"; from: -pageStack.width * 0.3; to: 0; duration: 350; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; from: 0.4; to: 1; duration: 350; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.98; to: 1.0; duration: 350; easing.type: Easing.OutCubic }
            }
        }
        popExit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "x"; from: 0; to: pageStack.width; duration: 350; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 350; easing.type: Easing.OutCubic }
            }
        }
        replaceEnter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300 }
                NumberAnimation { property: "scale"; from: 1.05; to: 1.0; duration: 300; easing.type: Easing.OutBack }
            }
        }
    }

    Component { id: homePage;   Home {} }
    Component { id: setupPage;  SetupWizard {} }
    Component { id: spotifyPage; Spotify {} }
    Component { id: youtubePage; YouTube {} }
    Component { id: browserPage; Browser {} }
    Component { id: castPage;    Cast {} }
    Component { id: settingsPage; Settings {} }
    Component { id: networkPage; Network {} }
    Component { id: bluetoothPage; Bluetooth {} }
    Component { id: aboutPage;   About {} }
    Component { id: appsPage;    Apps {} }

    function goTo(page) {
        if (page === currentPage) return;
        previousPage = currentPage;
        currentPage = page;
        switch (page) {
            case "home":      pageStack.replace(homePage);      break;
            case "setup":     pageStack.replace(setupPage);     break;
            case "spotify":   pageStack.replace(spotifyPage);   break;
            case "youtube":   pageStack.replace(youtubePage);   break;
            case "browser":   pageStack.replace(browserPage);   break;
            case "cast":      pageStack.replace(castPage);      break;
            case "settings":  pageStack.replace(settingsPage);  break;
            case "network":   pageStack.replace(networkPage);   break;
            case "bluetooth": pageStack.replace(bluetoothPage); break;
            case "about":     pageStack.replace(aboutPage);     break;
            case "apps":      pageStack.replace(appsPage);      break;
        }
    }

    function goBack() {
        goTo(previousPage || "home");
    }

    // ── Top bar ──────────────────────────────────────────────────────────
    TopBar {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 64
        z: 100
        visible: Settings.setupComplete
    }

    // ── Volume overlay ───────────────────────────────────────────────────
    VolumeOverlay {
        id: volumeOverlay
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 32
        z: 200
        visible: volumeOverlayVisible
    }

    // ── Power menu ───────────────────────────────────────────────────────
    PowerMenu {
        id: powerMenu
        anchors.fill: parent
        z: 300
        visible: powerMenuVisible
    }

    // ── Toast notifications ──────────────────────────────────────────────
    Column {
        id: toastStack
        anchors.top: topBar.visible ? topBar.bottom : parent.top
        anchors.topMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8
        z: 250

        Repeater {
            model: Notifications.notifications
            delegate: Toast {
                title: modelData.title
                body: modelData.body
                severity: modelData.severity
                onDismissed: Notifications.dismiss(modelData.id)
            }
        }
    }

    // ── Custom cursor (for air-mouse mode) ───────────────────────────────
    Image {
        id: customCursor
        source: "qrc:/icons/cursor.svg"
        width: 32; height: 32
        x: Input.cursorX - 16
        y: Input.cursorY - 16
        visible: Input.cursorVisible && cursorMode
        z: 999
        Behavior on x { SpringAnimation { spring: 4; damping: 0.3 } }
        Behavior on y { SpringAnimation { spring: 4; damping: 0.3 } }
    }

    // ── Global input handler ─────────────────────────────────────────────
    Connections {
        target: Input
        function onNavEvent(direction) {
            if (direction === "back") {
                if (currentPage !== "home" && currentPage !== "setup") {
                    goBack();
                }
            }
        }
        function onSystemEvent(action) {
            if (action === "home") {
                goTo("home");
            } else if (action === "menu") {
                // Show context menu if applicable
            } else if (action === "power") {
                powerMenuVisible = !powerMenuVisible;
            } else if (action === "volumeUp") {
                Settings.volume = Math.min(100, Settings.volume + 5);
                showVolumeOverlay();
            } else if (action === "volumeDown") {
                Settings.volume = Math.max(0, Settings.volume - 5);
                showVolumeOverlay();
            } else if (action === "mute") {
                Settings.muted = !Settings.muted;
                showVolumeOverlay();
            }
        }
        function onCursorMoved() {
            cursorMode = true;
        }
    }

    function showVolumeOverlay() {
        volumeOverlayVisible = true;
        volumeOverlayHideTimer.restart();
    }
    Timer {
        id: volumeOverlayHideTimer
        interval: 1500
        onTriggered: volumeOverlayVisible = false
    }

    // ── Keyboard shortcuts ───────────────────────────────────────────────
    Shortcut { sequence: "Escape"; onActivated: {
        if (currentPage !== "home" && currentPage !== "setup") goBack();
        else if (powerMenuVisible) powerMenuVisible = false;
    }}
    Shortcut { sequence: "Meta+H"; onActivated: goTo("home") }
    Shortcut { sequence: "Meta+S"; onActivated: goTo("spotify") }
    Shortcut { sequence: "Meta+Y"; onActivated: goTo("youtube") }
    Shortcut { sequence: "Meta+B"; onActivated: goTo("browser") }
    Shortcut { sequence: "Meta+C"; onActivated: goTo("cast") }
    Shortcut { sequence: "Meta+,"; onActivated: goTo("settings") }
    Shortcut { sequence: "Ctrl+Alt+Del"; onActivated: powerMenuVisible = true }

    // ── Watch for setup completion ───────────────────────────────────────
    Connections {
        target: Settings
        function onSetupCompleteChanged() {
            if (Settings.setupComplete) goTo("home");
        }
    }
}
