#!/bin/sh
set -e
mkdir -p /secrets /var/run/xl2tpd
modprobe ppp_generic 2>/dev/null || true; modprobe ppp_async 2>/dev/null || true
[ -e /dev/ppp ] || mknod /dev/ppp c 108 0
[ -d /sys/module/ppp_generic ] || echo "WARN: ppp_generic not loaded on host (modprobe ppp_generic)"
touch /secrets/chap-secrets; chmod 600 /secrets/chap-secrets
ln -sf /secrets/chap-secrets /etc/ppp/chap-secrets
exec xl2tpd -D -c /etc/xl2tpd/xl2tpd.conf -C /var/run/xl2tpd/l2tp-control
