#include "FileShelfModel.h"

#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QIcon>
#include <QMimeDatabase>
#include <QMimeType>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QStringList>

#include <utility>

namespace {
constexpr qsizetype kMaximumDisplayNameCharacters = 22;
constexpr qsizetype kDisplayNamePrefixCharacters = 13;
constexpr qsizetype kDisplayNameSuffixCharacters = 8;

void appendUnique(QStringList &values, const QString &value)
{
    const QString cleaned = value.trimmed();
    if (!cleaned.isEmpty() && !values.contains(cleaned))
        values.append(cleaned);
}

QString gtkIconThemeName()
{
    const QString configRoot = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    const QStringList settingsPaths{
        QDir(configRoot).filePath(QStringLiteral("gtk-4.0/settings.ini")),
        QDir(configRoot).filePath(QStringLiteral("gtk-3.0/settings.ini")),
    };

    for (const QString &settingsPath : settingsPaths) {
        if (!QFileInfo::exists(settingsPath))
            continue;
        QSettings settings(settingsPath, QSettings::IniFormat);
        const QString themeName = settings.value(QStringLiteral("Settings/gtk-icon-theme-name")).toString().trimmed();
        if (!themeName.isEmpty())
            return themeName;
    }
    return QString();
}

QStringList iconThemeRoots()
{
    QStringList roots;
    for (const QString &path : QIcon::themeSearchPaths())
        appendUnique(roots, path);
    appendUnique(roots, QDir::home().filePath(QStringLiteral(".icons")));
    for (const QString &path : QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation))
        appendUnique(roots, QDir(path).filePath(QStringLiteral("icons")));
    return roots;
}

void appendInheritedThemes(QStringList &themes, const QStringList &roots)
{
    for (qsizetype index = 0; index < themes.size(); ++index) {
        const QString themeName = themes.at(index);
        for (const QString &root : roots) {
            const QString indexPath = QDir(root).filePath(themeName + QStringLiteral("/index.theme"));
            if (!QFileInfo::exists(indexPath))
                continue;

            QSettings settings(indexPath, QSettings::IniFormat);
            const QStringList inherited = settings.value(QStringLiteral("Icon Theme/Inherits"))
                .toString().split(u',', Qt::SkipEmptyParts);
            for (const QString &inheritedTheme : inherited)
                appendUnique(themes, inheritedTheme);
            break;
        }
    }
}

QString findIconFile(const QString &themeRoot, const QString &iconName)
{
    if (themeRoot.isEmpty() || iconName.isEmpty())
        return QString();

    static const QStringList directories{
        QStringLiteral("scalable/mimetypes"),
        QStringLiteral("scalable/places"),
        QStringLiteral("symbolic/mimetypes"),
        QStringLiteral("symbolic/places"),
        QStringLiteral("256x256/mimetypes"),
        QStringLiteral("256x256/places"),
        QStringLiteral("128x128/mimetypes"),
        QStringLiteral("128x128/places"),
        QStringLiteral("96x96/mimetypes"),
        QStringLiteral("96x96/places"),
        QStringLiteral("64x64/mimetypes"),
        QStringLiteral("64x64/places"),
        QStringLiteral("48x48/mimetypes"),
        QStringLiteral("48x48/places"),
        QStringLiteral("32x32/mimetypes"),
        QStringLiteral("32x32/places"),
    };
    static const QStringList extensions{QStringLiteral(".svg"), QStringLiteral(".png"), QStringLiteral(".xpm")};

    for (const QString &directory : directories) {
        for (const QString &extension : extensions) {
            const QString candidate = QDir(themeRoot).filePath(directory + u'/' + iconName + extension);
            if (QFileInfo::exists(candidate))
                return QFileInfo(candidate).absoluteFilePath();
        }
    }

    QDirIterator iterator(themeRoot, QDir::Files, QDirIterator::Subdirectories);
    while (iterator.hasNext()) {
        const QString candidate = iterator.next();
        const QFileInfo candidateInfo(candidate);
        if (candidateInfo.completeBaseName() == iconName
            && extensions.contains(u'.' + candidateInfo.suffix().toLower())) {
            return candidateInfo.absoluteFilePath();
        }
    }
    return QString();
}
}

FileShelfModel::FileShelfModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int FileShelfModel::count() const
{
    return m_entries.size();
}

int FileShelfModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_entries.size();
}

QVariant FileShelfModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_entries.size())
        return QVariant();

    const Entry &entry = m_entries.at(index.row());
    switch (role) {
    case Qt::DisplayRole:
    case DisplayNameRole:
        return entry.displayName;
    case FileUrlRole:
        return entry.fileUrl;
    case UriRole:
        return entry.fileUrl.toString(QUrl::FullyEncoded);
    case FilePathRole:
        return entry.filePath;
    case FileNameRole:
        return entry.fileName;
    case IconNameRole:
        return entry.iconName;
    case FallbackIconNameRole:
        return entry.fallbackIconName;
    case IconSourceRole:
        return entry.iconSource;
    case DirectoryRole:
        return entry.directory;
    case ExistsRole:
        return entry.exists;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> FileShelfModel::roleNames() const
{
    return {
        {FileUrlRole, "fileUrl"},
        {UriRole, "uri"},
        {FilePathRole, "filePath"},
        {FileNameRole, "fileName"},
        {DisplayNameRole, "displayName"},
        {IconNameRole, "iconName"},
        {FallbackIconNameRole, "fallbackIconName"},
        {IconSourceRole, "iconSource"},
        {DirectoryRole, "directory"},
        {ExistsRole, "exists"},
    };
}

QList<QUrl> FileShelfModel::urlsFromVariant(const QVariant &value)
{
    QList<QUrl> urls;

    if (value.canConvert<QUrl>() && value.metaType().id() != QMetaType::QStringList
        && value.metaType().id() != QMetaType::QVariantList) {
        const QUrl url = value.toUrl();
        if (url.isValid())
            urls.append(url);
        return urls;
    }

    const QVariantList values = value.toList();
    for (const QVariant &item : values) {
        QUrl url = item.toUrl();
        if (url.isEmpty())
            url = QUrl::fromUserInput(item.toString(), QDir::currentPath(), QUrl::AssumeLocalFile);
        if (url.isValid())
            urls.append(url);
    }
    return urls;
}

QList<QUrl> FileShelfModel::urlsFromUriList(const QString &uriList)
{
    QList<QUrl> urls;
    const QStringList lines = uriList.split(QRegularExpression(QStringLiteral("[\\r\\n]+")), Qt::SkipEmptyParts);
    for (QString line : lines) {
        line = line.trimmed();
        if (line.isEmpty() || line.startsWith(u'#')
            || line.compare(QStringLiteral("copy"), Qt::CaseInsensitive) == 0
            || line.compare(QStringLiteral("cut"), Qt::CaseInsensitive) == 0) {
            continue;
        }

        const QUrl url = QUrl::fromEncoded(line.toUtf8(), QUrl::StrictMode);
        if (url.isValid())
            urls.append(url);
    }
    return urls;
}

QString FileShelfModel::shortenedFileName(const QString &fileName)
{
    if (fileName.size() <= kMaximumDisplayNameCharacters)
        return fileName;

    return fileName.left(kDisplayNamePrefixCharacters)
        + QChar(0x2026)
        + fileName.right(kDisplayNameSuffixCharacters);
}

QString FileShelfModel::themedIconSource(const QString &iconName, const QString &fallbackIconName)
{
    static QHash<QString, QString> cache;
    const QString cacheKey = iconName + u'\n' + fallbackIconName;
    const auto cached = cache.constFind(cacheKey);
    if (cached != cache.cend())
        return cached.value();

    const QStringList roots = iconThemeRoots();
    QStringList themes;
    appendUnique(themes, QIcon::themeName());
    appendUnique(themes, gtkIconThemeName());
    appendUnique(themes, QStringLiteral("Adwaita"));
    appendUnique(themes, QStringLiteral("hicolor"));
    appendInheritedThemes(themes, roots);

    const QStringList iconNames{iconName, fallbackIconName, QStringLiteral("text-x-generic")};
    for (const QString &theme : themes) {
        for (const QString &root : roots) {
            const QString themeRoot = QDir(root).filePath(theme);
            if (!QFileInfo(themeRoot).isDir())
                continue;
            for (const QString &name : iconNames) {
                const QString path = findIconFile(themeRoot, name);
                if (!path.isEmpty()) {
                    const QString source = QUrl::fromLocalFile(path).toString(QUrl::FullyEncoded);
                    cache.insert(cacheKey, source);
                    return source;
                }
            }
        }
    }

    cache.insert(cacheKey, QString());
    return QString();
}

FileShelfModel::Entry FileShelfModel::entryForUrl(const QUrl &sourceUrl)
{
    Entry entry;
    if (!sourceUrl.isLocalFile())
        return entry;

    const QFileInfo info(sourceUrl.toLocalFile());
    const QString absolutePath = info.absoluteFilePath();
    if (absolutePath.isEmpty())
        return entry;

    entry.fileUrl = QUrl::fromLocalFile(absolutePath);
    entry.filePath = absolutePath;
    entry.fileName = info.fileName().isEmpty() ? absolutePath : info.fileName();
    entry.displayName = shortenedFileName(entry.fileName);
    entry.exists = info.exists();
    entry.directory = info.isDir();

    if (entry.directory) {
        entry.iconName = QStringLiteral("folder");
        entry.fallbackIconName = QStringLiteral("inode-directory");
        entry.iconSource = themedIconSource(entry.iconName, entry.fallbackIconName);
        return entry;
    }

    QMimeDatabase mimeDatabase;
    const QMimeType mimeType = mimeDatabase.mimeTypeForFile(info, QMimeDatabase::MatchDefault);
    entry.iconName = mimeType.iconName();
    entry.fallbackIconName = mimeType.genericIconName();
    if (entry.iconName.isEmpty())
        entry.iconName = QStringLiteral("text-x-generic");
    if (entry.fallbackIconName.isEmpty())
        entry.fallbackIconName = QStringLiteral("unknown");
    entry.iconSource = themedIconSource(entry.iconName, entry.fallbackIconName);
    return entry;
}

QString FileShelfModel::identityForUrl(const QUrl &url)
{
    if (!url.isLocalFile())
        return QString();

    return QDir::cleanPath(QFileInfo(url.toLocalFile()).absoluteFilePath());
}

bool FileShelfModel::addUrl(const QUrl &url)
{
    const Entry entry = entryForUrl(url);
    if (entry.fileUrl.isEmpty() || !entry.exists)
        return false;

    const QString identity = identityForUrl(entry.fileUrl);
    for (const Entry &existing : std::as_const(m_entries)) {
        if (identityForUrl(existing.fileUrl) == identity)
            return false;
    }

    const int newRow = m_entries.size();
    beginInsertRows(QModelIndex(), newRow, newRow);
    m_entries.append(entry);
    endInsertRows();
    emit countChanged();
    return true;
}

int FileShelfModel::addUrls(const QVariant &urls)
{
    int added = 0;
    for (const QUrl &url : urlsFromVariant(urls)) {
        if (addUrl(url))
            ++added;
    }
    return added;
}

int FileShelfModel::addUriList(const QString &uriList)
{
    int added = 0;
    for (const QUrl &url : urlsFromUriList(uriList)) {
        if (addUrl(url))
            ++added;
    }
    return added;
}

QVariantMap FileShelfModel::get(int index) const
{
    if (index < 0 || index >= m_entries.size())
        return QVariantMap();

    const Entry &entry = m_entries.at(index);
    return {
        {QStringLiteral("fileUrl"), entry.fileUrl},
        {QStringLiteral("uri"), entry.fileUrl.toString(QUrl::FullyEncoded)},
        {QStringLiteral("filePath"), entry.filePath},
        {QStringLiteral("fileName"), entry.fileName},
        {QStringLiteral("displayName"), entry.displayName},
        {QStringLiteral("iconName"), entry.iconName},
        {QStringLiteral("fallbackIconName"), entry.fallbackIconName},
        {QStringLiteral("iconSource"), entry.iconSource},
        {QStringLiteral("directory"), entry.directory},
        {QStringLiteral("exists"), entry.exists},
    };
}

bool FileShelfModel::move(int sourceIndex, int targetIndex)
{
    if (sourceIndex < 0 || sourceIndex >= m_entries.size()
        || targetIndex < 0 || targetIndex >= m_entries.size()) {
        return false;
    }
    if (sourceIndex == targetIndex)
        return true;

    const int destinationChild = targetIndex > sourceIndex ? targetIndex + 1 : targetIndex;
    if (!beginMoveRows(QModelIndex(), sourceIndex, sourceIndex, QModelIndex(), destinationChild))
        return false;
    m_entries.move(sourceIndex, targetIndex);
    endMoveRows();
    return true;
}

bool FileShelfModel::removeAt(int index)
{
    if (index < 0 || index >= m_entries.size())
        return false;

    beginRemoveRows(QModelIndex(), index, index);
    m_entries.removeAt(index);
    endRemoveRows();
    emit countChanged();
    return true;
}

void FileShelfModel::clear()
{
    if (m_entries.isEmpty())
        return;

    beginResetModel();
    m_entries.clear();
    endResetModel();
    emit countChanged();
}

void FileShelfModel::refresh()
{
    for (int index = m_entries.size() - 1; index >= 0; --index) {
        const Entry refreshed = entryForUrl(m_entries.at(index).fileUrl);
        if (!refreshed.exists) {
            beginRemoveRows(QModelIndex(), index, index);
            m_entries.removeAt(index);
            endRemoveRows();
            emit countChanged();
            continue;
        }

        m_entries[index] = refreshed;
        const QModelIndex changedIndex = createIndex(index, 0);
        emit dataChanged(changedIndex, changedIndex);
    }
}
