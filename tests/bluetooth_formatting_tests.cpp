#include <QFile>
#include <QJSEngine>
#include <QJSValue>
#include <QtTest>

class BluetoothFormattingTests : public QObject
{
    Q_OBJECT

private:
    QJSEngine m_engine;

    QJSValue call(const QString &name, const QJSValueList &arguments)
    {
        return m_engine.globalObject().property(name).call(arguments);
    }

private slots:
    void initTestCase()
    {
        QFile source(QStringLiteral(BLUETOOTH_FORMATTING_SOURCE));
        QVERIFY2(source.open(QIODevice::ReadOnly | QIODevice::Text), qPrintable(source.errorString()));
        QString script = QString::fromUtf8(source.readAll());
        script.remove(QStringLiteral(".pragma library"));
        const QJSValue result = m_engine.evaluate(script, source.fileName());
        QVERIFY2(!result.isError(), qPrintable(result.toString()));
    }

    void prefersUserFacingAlias()
    {
        QCOMPARE(call(QStringLiteral("friendlyName"), {
            QStringLiteral("Desk headphones"),
            QStringLiteral("UGREEN HiTune Max5c"),
            QStringLiteral("F7:D3:82:04:C2:D6")
        }).toString(), QStringLiteral("Desk headphones"));
    }

    void rejectsAddressPlaceholders()
    {
        const QString address = QStringLiteral("7A:70:47:67:12:DE");
        QVERIFY(call(QStringLiteral("isAddressLike"), {
            QStringLiteral("7A-70-47-67-12-DE"), address
        }).toBool());
        QVERIFY(call(QStringLiteral("friendlyName"), {
            QStringLiteral("7A-70-47-67-12-DE"), QString(), address
        }).toString().isEmpty());
    }

    void keepsProductNamesContainingHexCharacters()
    {
        QVERIFY(!call(QStringLiteral("isAddressLike"), {
            QStringLiteral("WH-1000XM5"), QStringLiteral("00:11:22:33:44:55")
        }).toBool());
    }

    void fallsBackToDeviceType()
    {
        QCOMPARE(call(QStringLiteral("displayName"), {
            QString(), QString(), QStringLiteral("00:11:22:33:44:55"), QStringLiteral("audio-headset")
        }).toString(), QStringLiteral("Headset"));
        QCOMPARE(call(QStringLiteral("displayName"), {
            QString(), QString(), QStringLiteral("00:11:22:33:44:55"), QString()
        }).toString(), QStringLiteral("Unknown device"));
    }

    void normalizesAddressForSecondaryText()
    {
        QCOMPARE(call(QStringLiteral("addressLabel"), {
            QStringLiteral("aa-bb-cc-dd-ee-ff")
        }).toString(), QStringLiteral("AA:BB:CC:DD:EE:FF"));
    }
};

QTEST_MAIN(BluetoothFormattingTests)
#include "bluetooth_formatting_tests.moc"
