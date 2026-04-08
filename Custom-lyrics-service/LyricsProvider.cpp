#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDebug>
#include <QProcess>
#include <QVariantMap>

#include "LyricsProvider.h"
#include "qcontainerfwd.h"
#include "qlogging.h"

static QString decodeOctalEscapes(const QString &input) {
    QByteArray inputBytes = input.toUtf8();
    QByteArray resultBytes;
    
    for (int i = 0; i < inputBytes.length(); i++) {
        if (inputBytes[i] == '\\' && i + 3 < inputBytes.length()) {
            QByteArray octal = inputBytes.mid(i + 1, 3);
            bool ok;
            int byte = octal.toInt(&ok, 8);
            if (ok) {
                resultBytes.append(static_cast<char>(byte));
                i += 3;
                continue;
            }
        }
        resultBytes.append(inputBytes[i]);
    }
    
    return QString::fromUtf8(resultBytes);
}

LyricsProvider::LyricsProvider(QObject *parent)
    : QObject(parent), m_mprisInterface(nullptr) {

  QDBusConnection bus = QDBusConnection::sessionBus();
  m_mprisInterface = new QDBusInterface(
      // "org.mpris.MediaPlayer2.playerctld"
      "org.mpris.MediaPlayer2.chromium.instance150484",
      "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", bus, this);
}
// void LyricsProvider::fetchCurrentSong() {
//   QDBusReply<QDBusVariant> reply = m_mprisInterface->call(
//       "Get", "org.mpris.MediaPlayer2.Player", "Metadata");
//
//   if (reply.isValid()) {
//     QVariantMap meta = reply.value().variant().toMap();
//     qDebug() << "All keys:" << meta.keys(); // 打印所有 key
//     qDebug() << "All data:" << meta;        // 打印所有数据
//
//     QString title = meta["xesam:title"].toString();
//     QString Artist = meta["xesam:artist"].toStringList().join(", ");
//     qDebug() << "Title: " << title << "; Artist: " << Artist;
//
//   } else {
//     qWarning() << "Failed to get metadata:" << reply.error().message();
//   }
// }
void LyricsProvider::fetchCurrentSong() {
  QProcess process;
  process.start("busctl", {"--user", "get-property",
                           "org.mpris.MediaPlayer2.chromium.instance150484",
                           "/org/mpris/MediaPlayer2",
                           "org.mpris.MediaPlayer2.Player", "Metadata"});
  process.waitForFinished(500);

  QString output = QString::fromUtf8(process.readAllStandardOutput());

  // 简单字符串解析
  QString title, artist;

  // 找 xesam:title
  int titlePos = output.indexOf("xesam:title");
  if (titlePos != -1) {
    int start = output.indexOf("\"", titlePos + 12);
    int end = output.indexOf("\"", start + 1);
    title = output.mid(start + 1, end - start - 1);
  }

  // 找 xesam:artist
  int artistPos = output.indexOf("xesam:artist");
  if (artistPos != -1) {
    int start = output.indexOf("\"", artistPos + 13);
    int end = output.indexOf("\"", start + 1);
    artist = output.mid(start + 1, end - start - 1);
  }

  qDebug() << "Title:" << decodeOctalEscapes(title);
  qDebug() << "Artist:" << decodeOctalEscapes(artist);
}
