#!/bin/sh
set -ex

dnf groupinstall -y "Server with GUI"
dnf install -y epel-release
dnf groupinstall -y xfce
wget https://raw.githubusercontent.com/TurboVNC/repo/main/TurboVNC.repo -O /etc/yum.repos.d/TurboVNC.repo
wget https://virtualgl.com/pmwiki/uploads/Downloads/VirtualGL.repo -O /etc/yum.repos.d/VirtualGL.repo
dnf install --enablerepo=powertools -y turbovnc git VirtualGL turbojpeg xorg-x11-apps nmap

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
