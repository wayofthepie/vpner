#!/usr/bin/env bash

sed -i "s/VPN_URL/$1/" /var/tmp/csd.sh
iptables -t nat -A POSTROUTING -o tun+ -j MASQUERADE
openconnect -u$2 $1 --csd-user=root --csd-wrapper=/var/tmp/csd.sh
