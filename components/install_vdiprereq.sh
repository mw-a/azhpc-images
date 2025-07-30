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

if [ "$VDI" = "DCV" ] ; then
	cat <<-EOF >dcvrpmkey
		-----BEGIN PGP PUBLIC KEY BLOCK-----
		Version: GnuPG v2.0.22 (GNU/Linux)

		mQENBFnObokBCAColwxCCvgj2KniCq4pqh9REGj6CjaOUYcUFSlf+eCwcNhaUWAx
		+49rkkEWtcc/uJEE4ZL+q+r3imoH8KHFr8HBsi10xktPohxdhvKtEcG9EZIFH1zC
		xmTZCab7jrz54rZvc1+tGlmjhQLIQSVros7Sfq6ufNPz/eCj1wTU5o9JIrie87sG
		rciY408EOfHstJOE8Esa24IDJg+/dF/CxoAi77cKadqNNWq4z1rzF8ngJPLybbaS
		GxYnIbLr+0hq8Orlb/jQIenrlYSJrKQPVuPRwA7JUpxwNWCnjh32vC9/pjTXh0W5
		FXLy2PsJClXnzSNIaqHdgs6rJZjep55EtrZ9ABEBAAG0J05JQ0Ugcy5yLmwuIDxz
		dXBwb3J0QG5pY2Utc29mdHdhcmUuY29tPokBVAQTAQgAPgIbAwULCQgHAgYVCAkK
		CwIEFgIDAQIeAQIXgBYhBFue68hkRJcB9s5WahG1xwoXDGEUBQJlHrl6BQkPErHx
		AAoJEBG1xwoXDGEUvHUIAIA/lDdXYG940B1OaHc2PKa82E1omJteqh3DNPfDA0Xy
		ZZsAHt2GsNGsfgCDfYuNkSwyqFPC5ZmJ4ejSo9L48vxj/Ccsq7WmzTRxkKd+562y
		hZnIaKsiRlAR0C3WQVcn+OMqPewZFk7WPPnR1Bv99yCe9cVi3DChfSvmztMgcAAT
		JetyMR2z8myoWApOR0j/C/7AcWHd7UvM3j+WXwv21jKlCiZyZsDswe9wG8N5R7rO
		W/SZ0VGS4RH1LR/W5CWXU049DoU/nu2NyDHqUu0asiUJC2sg6sF4LDwstwRBb9UT
		CUhvoYrc8V3GoLyz/gREQ3aPJoTJ5gbe7I6Qme0Mb9S5AQ0EWc5uiQEIALKIH9li
		yci5tXotIX5/NjWSCcLONq8TjYOlEjZvSKE4MCy6acaYTeaJBDXdJxOB+hosqzMv
		NCRv2K+D3YPteJ43LpjdBm9ixJ672N4KoKelcvPKl4A5vF66pr2VQ+0hWt0Gthv8
		HCvvbogeVJ0GE57QKNFVjji2pqkSvW9/znDjlW2qNUP560i72fPVUmyt2iFzlccH
		rfI8FPHe99CeTcpSzCpz4fSj2MlB9OpazdlycUyegiiGqaORWs3vF1/FtcryNM4d
		wgjdXoAH5mFR1+VRhXjxHP19akexxM6XNRSIGz0qlH4iMY6ueBFtLJ+1b4Klxk5S
		St/6TCyqCnUiue0AEQEAAYkBPAQYAQgAJgIbDBYhBFue68hkRJcB9s5WahG1xwoX
		DGEUBQJlHrmFBQkPErH8AAoJEBG1xwoXDGEUMlsH+gLw+y0v+9gt7rFqwRpyHgK/
		hRdQWUP5B3P9QpkS88OPe4A4LI6tBs1ihDv2qexkmb03uFN+rUxwVeRFKDXSGx/b
		qm7ZYTA7/n0WdfVsPUCwbq/+ujBKGOetkLuxwLxXU2yniVsgo33bEzSMtUxtNGW/
		j9tbHeXVqpfOYTf0QETikgJ2d9grh8jRBWxlzkiMN7hpmoogtq9nwt8kGORCDHyj
		WRdTM0VrmWKI9So/D518sRHCrNgeLGct5hfCsUC3WDM/T55iMrfiZYJ3ZPQsJtqk
		dcQers/1L/zzdNlfSAr9C/BsZa2zr+l6Wsw4knAZTy66LFuw0Zv97qO02B/I6/8=
		=Hm4H
		-----END PGP PUBLIC KEY BLOCK-----
	EOF
	rpm --import dcvrpmkey
	rm -f dcvrpmkey

	curl -L -o dcv.tar.gz https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-el8-x86_64.tgz
	echo a3038cb0119c9e287c08afb84c687e48896cb4e7af2f9c8a7724b5ae9226e718  dcv.tar.gz | sha256sum -c
	tar -xf dcv.tar.gz
	dnf install -y glx-utils nice-dcv-*x86_64/nice-{dcv-server,xdcv,dcv-web-viewer,dcv-gl,dcv-gltest,dcv-simple-external-authenticator}-*.el8.x86_64.rpm
	rm -rf dcv.tar.gz nice-dcv-*x86_64
fi
