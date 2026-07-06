#include "SetupWizard.h"
#include "SettingsManager.h"
#include <QSet>
#include <QMap>

SetupWizard::SetupWizard(QObject *parent)
    : QObject(parent), m_current(0), m_settings(nullptr)
{
    m_steps = {
        "welcome",       // Hello screen
        "language",      // Pick language
        "network",       // Connect to WiFi
        "bluetooth",     // Pair a remote / headphones
        "account",       // Sign in to Spotify (optional)
        "hostname",      // Set device name
        "timezone",      // Set timezone
        "complete"       // All done!
    };
}

void SetupWizard::setCurrentStep(int s) {
    if (s < 0) s = 0;
    if (s >= m_steps.size()) s = m_steps.size() - 1;
    if (m_current != s) {
        m_current = s;
        emit stepChanged();
    }
}

QString SetupWizard::currentTitle() const {
    if (m_current >= m_steps.size()) return QString();
    static const QMap<QString, QString> titles = {
        {"welcome",    "Welcome to ZAIos"},
        {"language",   "Choose your language"},
        {"network",    "Connect to Wi-Fi"},
        {"bluetooth",  "Pair devices"},
        {"account",    "Sign in (optional)"},
        {"hostname",   "Name your device"},
        {"timezone",   "Set your timezone"},
        {"complete",   "You're all set!"},
    };
    return titles.value(m_steps[m_current]);
}

QString SetupWizard::currentDesc() const {
    if (m_current >= m_steps.size()) return QString();
    static const QMap<QString, QString> descs = {
        {"welcome",    "Let's set up your TV OS in just a few steps."},
        {"language",   "Pick the language you want to use."},
        {"network",    "Connect to the internet to enable Spotify, YouTube, and more."},
        {"bluetooth",  "Pair a remote, headphones, or game controller."},
        {"account",    "Sign in to Spotify Premium for native playback, or skip to use Spotube (no premium needed)."},
        {"hostname",   "This is how your device appears on the network."},
        {"timezone",   "Used for the clock and scheduling."},
        {"complete",   "Enjoy ZAIos!"},
    };
    return descs.value(m_steps[m_current]);
}

bool SetupWizard::canSkip() const {
    if (m_current >= m_steps.size()) return false;
    static const QSet<QString> skippable = {
        "bluetooth", "account", "timezone",
    };
    return skippable.contains(m_steps[m_current]);
}

void SetupWizard::next() {
    if (m_current < m_steps.size() - 1) {
        m_current++;
        emit stepChanged();
    } else {
        finish();
    }
}

void SetupWizard::back() {
    if (m_current > 0) {
        m_current--;
        emit stepChanged();
    }
}

void SetupWizard::skip() {
    if (canSkip()) next();
}

void SetupWizard::finish() {
    if (m_settings) m_settings->setSetupComplete(true);
    emit finished();
}
