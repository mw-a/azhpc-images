#!/bin/sh
set -ex

dnf groupinstall -y "Server with GUI"
dnf install -y epel-release
dnf groupinstall -y xfce

cat <<EOF >/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-screensaver" version="1.0">
  <property name="lock" type="empty">
    <property name="enabled" type="bool" value="false" unlocked="root"/>
  </property>
</channel>
EOF

# no group for mate in EPEL - extracted from Fedora 40 comps.xml
dnf config-manager --set-enabled powertools
dnf install -y atril atril-caja atril-thumbnailer caja caja-actions caja-image-converter \
       caja-open-terminal caja-sendto caja-wallpaper caja-xattr-tags engrampa eom marco \
       mate-applets mate-backgrounds mate-calc mate-control-center mate-desktop \
       mate-dictionary mate-disk-usage-analyzer mate-icon-theme mate-media \
       mate-menus mate-menus-preferences-category-menu mate-notification-daemon \
       mate-panel mate-polkit mate-power-manager mate-screensaver mate-screenshot \
       mate-search-tool mate-session-manager mate-settings-daemon mate-system-log \
       mate-system-monitor mate-terminal mate-themes mate-user-admin mate-user-guide \
       mozo pluma seahorse seahorse-caja slick-greeter-mate

# provide new-enough gtk-layer-shell for mate from epel on 8.7
[ "$(cat /etc/redhat-release  | awk '{print $3}')" != "8.7" ] || \
       dnf install -y https://archive.fedoraproject.org/pub/archive/epel/8.8/Everything/x86_64/Packages/g/gtk-layer-shell-0.8.1-1.el8.x86_64.rpm

dnf install -y chromium java-11
