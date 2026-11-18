#!/bin/sh
set -e
: "${VPN_TENANT_ID:?}" "${WG_ENDPOINT:?}" "${SERVER_HOST:?}"
case "$VPN_TENANT_ID" in *[!a-z0-9-]*|"") echo "ERROR: TENANT_ID must be a-z 0-9 -"; exit 1;; esac
D=/data; S=/secrets/chap-secrets
mkdir -p $D/clients /secrets; chmod 700 $D

# ---- auto-register this tenant in the shared L2TP gateway ----
(
  flock 9
  touch $S; chmod 600 $S
  if [ ! -f $D/l2tp.cred ]; then
    if grep -qE "^#?\"$VPN_TENANT_ID\" " $S; then echo "ERROR: TENANT_ID '$VPN_TENANT_ID' already used"; exit 1; fi
    idx=$(cat /secrets/.counter 2>/dev/null || echo 0); echo $((idx+1)) > /secrets/.counter
    pw=$(head -c 24 /dev/urandom | base64 | tr -d '/+=\n' | cut -c1-20)
    echo "$pw 169.254.$((idx/250+1)).$((idx%250+2))" > $D/l2tp.cred
  fi
  read pw ip < $D/l2tp.cred
  grep -qE "^\"$VPN_TENANT_ID\" " $S || echo "\"$VPN_TENANT_ID\" * \"$pw\" $ip" >> $S
) 9>/secrets/.lock || exit 1
read PW TIP < $D/l2tp.cred

cat > $D/mikrotik.rsc <<RSC
/interface l2tp-client add name=l2tp-cloud connect-to=$SERVER_HOST user=$VPN_TENANT_ID password=$PW disabled=no add-default-route=no dial-on-demand=no keepalive-timeout=10 max-mtu=1380 max-mru=1380 mrru=disabled allow=mschap2 profile=default use-ipsec=no comment=cloud-vpn
/ip firewall filter add chain=input in-interface=l2tp-cloud action=accept place-before=0 comment=cloud-vpn
/ip firewall filter add chain=forward in-interface=l2tp-cloud action=accept place-before=0 comment=cloud-vpn
/ip firewall filter add chain=forward out-interface=l2tp-cloud action=accept place-before=0 comment=cloud-vpn
/ip firewall nat add chain=srcnat src-address=169.254.255.1 action=masquerade comment=cloud-vpn
/system scheduler add name=l2tp-heal interval=30s comment=cloud-vpn on-event=":if ([/interface l2tp-client get l2tp-cloud running]=false || [/ping 169.254.255.1 count=3]=0) do={/interface l2tp-client disable l2tp-cloud; :delay 3s; /interface l2tp-client enable l2tp-cloud}"
RSC
chmod 600 $D/mikrotik.rsc
echo "=================== MIKROTIK SCRIPT (paste in router terminal) ==================="
cat $D/mikrotik.rsc
echo "=================================================================================="
echo "Show again anytime:  cat /data/mikrotik.rsc"

[ -f $D/server.key ] || { umask 077; wg genkey > $D/server.key; }
wg pubkey < $D/server.key > $D/server.pub

/firewall.sh

ip link del wg0 2>/dev/null || true
ip link add wg0 type wireguard
( umask 077
  { echo "[Interface]"; echo "PrivateKey = $(cat $D/server.key)"; echo "ListenPort = 51820"
    cat $D/clients/*.peer 2>/dev/null || true; } > /run/wg0.conf )
wg setconf wg0 /run/wg0.conf
ip addr add "${WG_SUBNET}.1/24" dev wg0
ip link set wg0 up mtu 1360
# ---- phones/users managed by env CLIENTS (comma separated) ----
CLIENTS=${CLIENTS:-admin}
for f in $D/clients/*.peer; do
  [ -f "$f" ] || continue
  n=$(basename "$f" .peer)
  case ",$CLIENTS," in *",$n,"*) ;; *) wg-client del "$n";; esac
done
for n in $(echo "$CLIENTS" | tr ',' ' '); do
  [ -f "$D/clients/$n.conf" ] || wg-client add "$n" >/dev/null || continue
  echo "=========== WireGuard config for: $n (copy to a .conf file or scan QR) ==========="
  wg-client show "$n"
done
echo "[vpn] tenant=$VPN_TENANT_ID ready."

while true; do
  for i in $(ip -o link | awk -F': ' '{print $2}' | cut -d@ -f1 | grep '^ppp'); do
    for c in $(echo "$LAN_RANGES" | tr ',' ' '); do
      ip route replace "$c" dev "$i" 2>/dev/null || true
    done
  done
  sleep 5
done
