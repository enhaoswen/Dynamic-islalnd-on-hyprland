#pragma once

#include <QDBusInterface>
#include <QObject>

class LyricsProvider : public QObject {
  Q_OBJECT

private:
  QDBusInterface *m_mprisInterface;

public:
  explicit LyricsProvider(QObject *parent = nullptr);
  Q_INVOKABLE void fetchCurrentSong();
};
