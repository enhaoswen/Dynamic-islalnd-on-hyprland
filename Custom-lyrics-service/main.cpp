#include "LyricsProvider.h"
#include <QCoreApplication>
#include <QDebug>

int main(int argc, char *argv[]) {
  QCoreApplication app(argc, argv);

  LyricsProvider provider;

  provider.fetchCurrentSong();

  return 0;
}
