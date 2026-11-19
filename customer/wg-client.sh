#!/bin/sh
# usage: wg-client add NAME | del NAME | show NAME | list
D=/data; C=$D/clients; mkdir -p $C
cmd="$1"; name="$2"
valid() { case "$name" in ""|*[!a-zA-Z0-9_-]*) echo "invalid name"; exit 1;; esac; }
case "$cmd" in
add)
  valid
  [ -f $C/$name.conf ] && { echo "exists"; exit 1; }
  cnt=$(ls $C/*.peer 2>/dev/null | wc -l)
  [ "$cnt" -lt "${MAX_CLIENTS:-3}" ] || { echo "limit reached (${MAX_CLIENTS:-3})"; exit 1; }
  n=2; while grep -qsF "AllowedIPs = ${WG_SUBNET}.$n/32" $C/*.peer; do n=$((n+1)); done
  [ $n -le 254 ] || { echo "no free ip"; exit 1; }
  ip="${WG_SUBNET}.$n"
  priv=$(wg genkey); pub=$(echo "$priv" | wg pubkey); psk=$(wg genpsk)
  ( umask 077
    printf '\n[Peer]\n# %s\nPublicKey = %s\nPresharedKey = %s\nAllowedIPs = %s/32\n' "$name" "$pub" "$psk" "$ip" > $C/$name.peer
    cat > $C/$name.conf <<CONF
[Interface]
PrivateKey = $priv
Address = $ip/32
MTU = 1360

[Peer]
PublicKey = $(cat $D/server.pub)
PresharedKey = $psk
Endpoint = $WG_ENDPOINT
AllowedIPs = $(echo "$LAN_RANGES" | sed 's/,/, /g')
PersistentKeepalive = 25
CONF
    echo "$psk" > /run/psk.$$; wg set wg0 peer "$pub" preshared-key /run/psk.$$ allowed-ips "$ip/32"; rm -f /run/psk.$$ )
  cat $C/$name.conf; echo; qrencode -t ansiutf8 < $C/$name.conf ;;
show) valid; cat $C/$name.conf; echo; qrencode -t ansiutf8 < $C/$name.conf ;;
del)
  valid
  pub=$(sed -n 's/^PublicKey = //p' $C/$name.peer 2>/dev/null)
  [ -n "$pub" ] && wg set wg0 peer "$pub" remove
  rm -f $C/$name.peer $C/$name.conf; echo "deleted $name" ;;
list) ls $C/*.peer 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.peer$//' ;;
*) echo "usage: wg-client add|del|show NAME | list"; exit 1;;
esac
