/*
 * Theme.qml — ZAIos design tokens (dark glassmorphism).
 *
 * Use: import ZAIos.Shell
 *      Theme.accent
 *
 * All UI components import these constants for consistency.
 */
pragma Singleton
import QtQuick

QtObject {
    // ── Color palette: deep navy + neon cyan + magenta accents ───────────
    readonly property color bgDeep:      "#050816"   // near-black navy
    readonly property color bgMid:       "#0A0F2C"   // mid navy
    readonly property color bgLight:     "#1A2151"   // elevated surface
    readonly property color glassLight:  "#1E2851"   // glass card top
    readonly property color glassDark:   "#0B1230"   // glass card bottom
    readonly property color accent:      "#00E5FF"   // neon cyan
    readonly property color accentSoft:  "#4DD0E1"   // soft cyan
    readonly property color accentMag:   "#FF2E93"   // neon magenta
    readonly property color accentPurple:"#9C4DFF"
    readonly property color textPrimary: "#FFFFFF"
    readonly property color textSecondary:"#B0BBD8"
    readonly property color textMuted:   "#6B7794"
    readonly property color success:     "#00FF88"
    readonly property color warning:     "#FFB800"
    readonly property color error:       "#FF3D5A"

    // ── Typography ───────────────────────────────────────────────────────
    readonly property string fontFamily: "Inter"
    readonly property int fontSizeXS:    11
    readonly property int fontSizeS:     13
    readonly property int fontSizeM:     16
    readonly property int fontSizeL:     20
    readonly property int fontSizeXL:    28
    readonly property int fontSizeXXL:   40
    readonly property int fontSizeXXXL:  64

    // ── Spacing ──────────────────────────────────────────────────────────
    readonly property int spaceXS: 4
    readonly property int spaceS:  8
    readonly property int spaceM:  16
    readonly property int spaceL:  24
    readonly property int spaceXL: 32
    readonly property int spaceXXL:48

    // ── Corner radius ────────────────────────────────────────────────────
    readonly property int radiusS: 8
    readonly property int radiusM: 14
    readonly property int radiusL: 20
    readonly property int radiusXL:28
    readonly property int radiusPill: 999

    // ── Motion ───────────────────────────────────────────────────────────
    readonly property int  durationFast:    150
    readonly property int  durationNormal:  300
    readonly property int  durationSlow:    500
    readonly property int  durationSlowest: 800
    readonly property real easingStandard: Easing.OutCubic
    readonly property real easingEmphasized: Easing.OutQuint
    readonly property real easingSpring: Easing.OutBack

    // ── Shadows ──────────────────────────────────────────────────────────
    readonly property string shadowSmall:  "0 2px 8px rgba(0,0,0,0.3)"
    readonly property string shadowMedium: "0 8px 24px rgba(0,0,0,0.4)"
    readonly property string shadowLarge:  "0 16px 48px rgba(0,0,0,0.5)"
    readonly property string glowAccent:   "0 0 24px rgba(0,229,255,0.4)"
}
