#!/bin/sh
set -ex

dnf install -y sssd sssd-tools oddjob oddjob-mkhomedir adcli krb5-workstation openldap-clients python3-ldap python3-dns
