#include "hoststreamsettings.h"
#include "streamingpreferences.h"

#include <QSettings>

#define SER_HOSTSTREAMSETTINGS "hoststreamsettings"
#define SER_WIDTH "width"
#define SER_HEIGHT "height"
#define SER_FPS "fps"
#define SER_BITRATE "bitrate"
#define SER_WINDOWMODE "windowmode"

static QString groupForHost(const QString& hostUuid)
{
    return QString(SER_HOSTSTREAMSETTINGS) + "/" + hostUuid;
}

HostStreamSettings HostStreamSettings::load(const QString& hostUuid)
{
    HostStreamSettings hostSettings;
    QSettings settings;

    settings.beginGroup(groupForHost(hostUuid));
    hostSettings.width = settings.value(SER_WIDTH, 0).toInt();
    hostSettings.height = settings.value(SER_HEIGHT, 0).toInt();
    hostSettings.fps = settings.value(SER_FPS, 0).toInt();
    hostSettings.bitrateKbps = settings.value(SER_BITRATE, 0).toInt();
    hostSettings.windowMode = settings.value(SER_WINDOWMODE, -1).toInt();
    settings.endGroup();

    // A resolution override needs both dimensions
    if (hostSettings.width <= 0 || hostSettings.height <= 0) {
        hostSettings.width = hostSettings.height = 0;
    }

    return hostSettings;
}

void HostStreamSettings::save(const QString& hostUuid) const
{
    QSettings settings;

    settings.remove(groupForHost(hostUuid));

    settings.beginGroup(groupForHost(hostUuid));
    if (width > 0 && height > 0) {
        settings.setValue(SER_WIDTH, width);
        settings.setValue(SER_HEIGHT, height);
    }
    if (fps > 0) {
        settings.setValue(SER_FPS, fps);
    }
    if (bitrateKbps > 0) {
        settings.setValue(SER_BITRATE, bitrateKbps);
    }
    if (windowMode >= 0) {
        settings.setValue(SER_WINDOWMODE, windowMode);
    }
    settings.endGroup();
}

void HostStreamSettings::remove(const QString& hostUuid)
{
    QSettings settings;
    settings.remove(groupForHost(hostUuid));
}

void HostStreamSettings::applyTo(StreamingPreferences* prefs) const
{
    bool modeChanged = false;

    if (width > 0 && height > 0) {
        prefs->width = width;
        prefs->height = height;
        modeChanged = true;
    }
    if (fps > 0) {
        prefs->fps = fps;
        modeChanged = true;
    }

    if (bitrateKbps > 0) {
        prefs->bitrateKbps = bitrateKbps;
    }
    else if (modeChanged && prefs->autoAdjustBitrate) {
        // Match the settings page: an unmodified bitrate follows the resolution and FPS
        prefs->bitrateKbps = StreamingPreferences::getDefaultBitrate(prefs->width, prefs->height,
                                                                     prefs->fps, prefs->enableYUV444);
    }

    if (windowMode >= 0) {
        prefs->windowMode = static_cast<StreamingPreferences::WindowMode>(windowMode);
    }
}

QVariantMap HostStreamSettings::toVariantMap() const
{
    QVariantMap map;
    map[SER_WIDTH] = width;
    map[SER_HEIGHT] = height;
    map[SER_FPS] = fps;
    map[SER_BITRATE] = bitrateKbps;
    map[SER_WINDOWMODE] = windowMode;
    return map;
}

HostStreamSettings HostStreamSettings::fromVariantMap(const QVariantMap& map)
{
    HostStreamSettings hostSettings;
    hostSettings.width = map.value(SER_WIDTH, 0).toInt();
    hostSettings.height = map.value(SER_HEIGHT, 0).toInt();
    hostSettings.fps = map.value(SER_FPS, 0).toInt();
    hostSettings.bitrateKbps = map.value(SER_BITRATE, 0).toInt();
    hostSettings.windowMode = map.value(SER_WINDOWMODE, -1).toInt();
    return hostSettings;
}
