#!/bin/sh
set -ex

dnf groupinstall -y "Server with GUI"
dnf install -y epel-release
dnf groupinstall -y xfce
wget https://raw.githubusercontent.com/TurboVNC/repo/main/TurboVNC.repo -O /etc/yum.repos.d/TurboVNC.repo
wget https://virtualgl.com/pmwiki/uploads/Downloads/VirtualGL.repo -O /etc/yum.repos.d/VirtualGL.repo
dnf install --enablerepo=powertools -y turbovnc git VirtualGL turbojpeg xorg-x11-apps nmap
# no group for mate in EPEL - extracted from Fedora 40 comps.xml
dnf install --enablerepo=powertools -y atril atril-caja atril-thumbnailer caja caja-actions caja-image-converter \
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

git clone https://github.com/novnc/websockify.git
cd websockify
git checkout v0.10.0
sed -i "s/'numpy'//g" setup.py
/usr/bin/python3 setup.py install
ln -s /usr/local/bin/websockify /usr/bin/websockify
echo '#!/bin/bash' > /etc/profile.d/desktop.sh
echo 'export PATH=/opt/TurboVNC/bin:$PATH' >> /etc/profile.d/desktop.sh
echo 'export WEBSOCKIFY_CMD=/usr/local/bin/websockify' >> /etc/profile.d/desktop.sh

cat <<EOF >/etc/profile.d/vglrun.sh
#!/bin/bash
ngpu=\$(/usr/sbin/lspci | grep NVIDIA | wc -l)
alias vglrun='/usr/bin/vglrun -d :0.\$(( \${port:-0} % \${ngpu:-1}))'
EOF

cat <<EOF >/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-screensaver" version="1.0">
  <property name="lock" type="empty">
    <property name="enabled" type="bool" value="false" unlocked="root"/>
  </property>
</channel>
EOF
