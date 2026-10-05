#pragma once

#include <QString>
#include <QVariantMap>

class StreamingPreferences;

// Per-host overrides of the global stream settings, stored by host UUID.
// A value of 0 (or -1 for the window mode) means "use the global setting".
class HostStreamSettings
{
public:
    static HostStreamSettings load(const QString& hostUuid);

    void save(const QString& hostUuid) const;

    static void remove(const QString& hostUuid);

    void applyTo(StreamingPreferences* prefs) const;

    QVariantMap toVariantMap() const;

    static HostStreamSettings fromVariantMap(const QVariantMap& map);

    int width = 0;
    int height = 0;
    int fps = 0;
    int bitrateKbps = 0;
    int windowMode = -1;
};
