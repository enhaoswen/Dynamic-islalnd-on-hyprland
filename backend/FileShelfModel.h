#pragma once

#include <QAbstractListModel>
#include <QUrl>
#include <QVariant>
#include <QtQml/qqml.h>

class FileShelfModel final : public QAbstractListModel {
    Q_OBJECT
    QML_NAMED_ELEMENT(FileShelf)
    QML_SINGLETON
    Q_PROPERTY(int count READ count NOTIFY countChanged FINAL)

public:
    enum Role {
        FileUrlRole = Qt::UserRole + 1,
        UriRole,
        FilePathRole,
        FileNameRole,
        DisplayNameRole,
        IconNameRole,
        FallbackIconNameRole,
        IconSourceRole,
        DirectoryRole,
        ExistsRole,
    };
    Q_ENUM(Role)

    explicit FileShelfModel(QObject *parent = nullptr);

    int count() const;
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE int addUrls(const QVariant &urls);
    Q_INVOKABLE int addUriList(const QString &uriList);
    Q_INVOKABLE QVariantMap get(int index) const;
    Q_INVOKABLE bool move(int sourceIndex, int targetIndex);
    Q_INVOKABLE bool removeAt(int index);
    Q_INVOKABLE void clear();
    Q_INVOKABLE void refresh();

signals:
    void countChanged();

private:
    struct Entry {
        QUrl fileUrl;
        QString filePath;
        QString fileName;
        QString displayName;
        QString iconName;
        QString fallbackIconName;
        QString iconSource;
        bool directory = false;
        bool exists = false;
    };

    static QList<QUrl> urlsFromVariant(const QVariant &value);
    static QList<QUrl> urlsFromUriList(const QString &uriList);
    static QString shortenedFileName(const QString &fileName);
    static QString themedIconSource(const QString &iconName, const QString &fallbackIconName);
    static Entry entryForUrl(const QUrl &url);
    static QString identityForUrl(const QUrl &url);
    bool addUrl(const QUrl &url);

    QList<Entry> m_entries;
};
