#!/bin/sh
set -ex

# mask broken package versions
sed -i -e "/^exclude=/s,$, sssd*-2.9.4-5.el8_10.2 libsss*-2.9.4-5.el8_10.2," /etc/dnf/dnf.conf

dnf install -y sssd sssd-tools oddjob oddjob-mkhomedir adcli krb5-workstation \
	openldap-clients python3-ldap python3-dns
