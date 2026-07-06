/*
 * SetupWizard.h — First-boot setup orchestrator.
 *
 * The actual wizard UI is in QML (qml/pages/SetupWizard.qml).
 * This class provides:
 *   - the ordered list of steps
 *   - state tracking (which step we're on, completion status)
 *   - side effects (apply language, set hostname, etc.)
 */
#ifndef SETUPWIZARD_H
#define SETUPWIZARD_H

#include <QObject>
#include <QStringList>

class SettingsManager;

class SetupWizard : public QObject {
    Q_OBJECT
    Q_PROPERTY(int      currentStep READ currentStep WRITE setCurrentStep NOTIFY stepChanged)
    Q_PROPERTY(int      totalSteps  READ totalSteps  CONSTANT)
    Q_PROPERTY(QString  currentTitle READ currentTitle NOTIFY stepChanged)
    Q_PROPERTY(QString  currentDesc  READ currentDesc  NOTIFY stepChanged)
    Q_PROPERTY(bool     canSkip     READ canSkip      NOTIFY stepChanged)

public:
    explicit SetupWizard(QObject *parent = nullptr);

    int totalSteps() const { return m_steps.size(); }
    int currentStep() const { return m_current; }
    void setCurrentStep(int s);
    QString currentTitle() const;
    QString currentDesc() const;
    bool canSkip() const;

    void setSettings(SettingsManager *s) { m_settings = s; }

    Q_INVOKABLE void next();
    Q_INVOKABLE void back();
    Q_INVOKABLE void skip();
    Q_INVOKABLE void finish();

signals:
    void stepChanged();
    void finished();
    void cancelled();

private:
    QStringList m_steps;
    int         m_current;
    SettingsManager *m_settings;
};

#endif
