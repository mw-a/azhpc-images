#!/bin/sh
set -ex

if [ "$VDI" != "NONE" ] ; then
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

	. /etc/os-release
	case "$VERSION_ID" in
		9.*) dnf config-manager --set-enabled crb ;;
		8.*) dnf config-manager --set-enabled powertools ;;
	esac

	# no group for mate in EPEL - extracted from Fedora 40 comps.xml
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

	# generic GUI application prerequisites
	dnf install -y chromium firefox java-11 java-1.8.0-openjdk kernel-tools \
		konqueror qt5-qtsvg xorg-x11-server-Xvfb mono-complete \
		vulkan-loader vulkan-tools vulkan-validation-layers \
		ksh xorg-x11-fonts-ISO8859-1-75dpi libXScrnSaver \
		apr-util mesa-dri-drivers dolphin kate kate-plugins

	# causes long timeouts and users aren't supposed to add packages anyway
	dnf remove -y PackageKit-command-not-found

	# VSCode
	cat <<EOF > /etc/yum.repos.d/vscode.repo
[vscode-yum]
name=vscode-yum
baseurl=https://packages.microsoft.com/yumrepos/vscode/
gpgcheck=1
enabled=1
EOF

	dnf install -y code

	useradd -m build

	# install extensions
	# https://stackoverflow.com/questions/34286515/how-to-install-visual-studio-code-extensions-from-command-line
	su - build -c "code --force --install-extension rogalmic.bash-debug --install-extension ms-python.python"

	# move system-wide
	# https://serverfault.com/questions/1105754/how-to-install-vscode-extensions-to-all-users
	rm -f /home/build/.vscode/extensions/extensions.json
	chown -R root: /home/build/.vscode/extensions/*
	mv /home/build/.vscode/extensions/* /usr/share/code/resources/app/extensions

	userdel -r build
fi

if [ "$VDI" = "VGL" ] ; then
	# VirtualGL for OOD
	wget https://raw.githubusercontent.com/TurboVNC/repo/main/TurboVNC.repo -O /etc/yum.repos.d/TurboVNC.repo
	wget https://virtualgl.com/pmwiki/uploads/Downloads/VirtualGL.repo -O /etc/yum.repos.d/VirtualGL.repo

	case "$VERSION_ID" in
		9.*) distpkgs= ;;
		8.*) distpkgs=xorg-x11-apps ;;
	esac

	dnf install -y turbovnc git VirtualGL turbojpeg nmap $distpkgs

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
fi
