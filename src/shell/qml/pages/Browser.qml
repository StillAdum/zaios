/*
 * Browser.qml — Embedded Chromium browser via QtWebEngine.
 *
 * Features:
 *   - URL/search bar (uses BrowserManager.normalizeUrl)
 *   - Back / Forward / Reload / Home buttons
 *   - Bookmark star
 *   - QtWebEngineView for actual page rendering
 *
 * The browser runs in the same process as the shell for performance.
 */
import QtQuick
import QtQuick.Layouts
import QtWebEngine
import ZAIos.Shell

Item {
    id: browserPage
    anchors.fill: parent

    Component.onCompleted: urlInput.forceActiveFocus();

    // ── URL bar + nav buttons ────────────────────────────────────────────
    RowLayout {
        id: toolbar
        anchors.top: parent.top
        anchors.topMargin: 88
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceXL
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceXL
        spacing: Theme.spaceS

        FocusButton {
            text: "←"; width: 48; height: 48; cornerRadius: 24
            onClicked: webview.goBack()
        }
        FocusButton {
            text: "→"; width: 48; height: 48; cornerRadius: 24
            onClicked: webview.goForward()
        }
        FocusButton {
            text: "⟳"; width: 48; height: 48; cornerRadius: 24
            onClicked: webview.reload()
        }
        FocusButton {
            text: "⌂"; width: 48; height: 48; cornerRadius: 24
            onClicked: {
                urlInput.text = "";
                webview.url = Browser.homeUrl;
            }
        }

        // URL input
        TextField {
            id: urlInput
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            placeholderText: "Search or type a URL"
            placeholderTextColor: Theme.textMuted
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeM
            selectByMouse: true

            background: Rectangle {
                radius: Theme.radiusPill
                color: Qt.rgba(30/255, 40/255, 81/255, 0.7)
                border.color: urlInput.activeFocus ? Theme.accent : Qt.rgba(255,255,255,0.08)
                border.width: urlInput.activeFocus ? 2 : 1
            }

            onAccepted: {
                var url = Browser.normalizeUrl(text);
                webview.url = url;
            }
        }

        // Bookmark star
        FocusButton {
            text: "★"; width: 48; height: 48; cornerRadius: 24
            onClicked: Browser.addBookmark(webview.url, webview.title)
        }
    }

    // ── Web view ─────────────────────────────────────────────────────────
    GlassCard {
        anchors.top: toolbar.bottom
        anchors.topMargin: Theme.spaceL
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceXL
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceXL
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spaceXL
        radius: Theme.radiusL

        WebEngineView {
            id: webview
            anchors.fill: parent
            anchors.margins: 1
            url: Browser.homeUrl
            onUrlChanged: urlInput.text = url
            onTitleChanged: Browser.addToHistory(url, title)

            // Force dark mode on supported sites
            userScripts: [
                WebEngineScript {
                    name: "dark-mode"
                    sourceCode: `
                        document.documentElement.style.filter = 'invert(1) hue-rotate(180deg)';
                        document.documentElement.style.background = '#000';
                    `
                    injectionPoint: WebEngineScript.DocumentReady
                    worldId: WebEngineScript.MainWorld
                }
            ]
        }

        // Loading progress bar
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 3
            color: "transparent"

            Rectangle {
                width: parent.width * webview.loadProgress / 100
                height: parent.height
                color: Theme.accent
                visible: webview.loadProgress < 100

                Behavior on width { NumberAnimation { duration: Theme.durationFast } }
            }
        }
    }
}
