/*
 * Glassmorphism.qml — Reusable glass blur + gradient helpers.
 *
 * Provides:
 *   - GlassEffect: applies blur + tint over whatever is behind it
 *   - gradientStops: pre-baked gradient stops for glass cards
 *
 * The blur is done with MultiEffect (Qt 6.5+). For older Qt, falls back
 * to a semi-transparent gradient.
 */
import QtQuick

QtObject {
    // Pre-baked gradient stops for a glass card top→bottom
    readonly property var glassGradient: [
        { stop: 0.0, color: Qt.rgba(30/255, 40/255, 81/255, 0.7) },   // #1E2851 70%
        { stop: 1.0, color: Qt.rgba(11/255, 18/255, 48/255, 0.85) }   // #0B1230 85%
    ]

    // Glow gradient for focused items
    readonly property var focusGlow: [
        { stop: 0.0, color: Qt.rgba(0, 229/255, 1, 0.6) },
        { stop: 1.0, color: Qt.rgba(0, 229/255, 1, 0.0) }
    ]

    function makeGlass(component) {
        // Apply blur effect to a component (placeholder for inline use)
        return component;
    }
}
