#!/bin/sh
# Default deny. Tunnel users can NEVER reach eth+ (internet / docker / other tenants).
iptables -F; iptables -X; iptables -t mangle -F
iptables -P INPUT DROP; iptables -P FORWARD DROP; iptables -P OUTPUT DROP

# INPUT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -i eth+ -p udp --dport 51820 -j ACCEPT          # WireGuard
iptables -A INPUT -i eth+ -p tcp --dport 20211 -j ACCEPT          # NetAlertX via Traefik
iptables -A INPUT -i wg0  -p tcp --dport 20211 -j ACCEPT          # NetAlertX via WireGuard
iptables -A INPUT -i wg0  -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -i ppp+ -p icmp --icmp-type echo-request -j ACCEPT   # router heartbeat

# FORWARD
iptables -A FORWARD -o eth+ -j DROP
iptables -A FORWARD -i eth+ -j DROP
iptables -A FORWARD -i wg0 -o wg0 -j DROP                          # phones can't see each other
iptables -A FORWARD -i wg0  -o ppp+ -j ACCEPT
iptables -A FORWARD -i ppp+ -o wg0  -j ACCEPT
iptables -t nat -C POSTROUTING -o ppp+ -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -o ppp+ -j MASQUERADE
iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# OUTPUT (container's own traffic: dashboard/scans/alerts)
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -o wg0 -j ACCEPT
iptables -A OUTPUT -o ppp+ -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -o eth+ -p udp --sport 51820 -j ACCEPT          # WireGuard rekey
iptables -A OUTPUT -o eth+ -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -o eth+ -p tcp --dport 53 -j ACCEPT
for n in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16 100.64.0.0/10; do
  iptables -A OUTPUT -o eth+ -d "$n" -j DROP                        # no docker/host/other tenants
done
iptables -A OUTPUT -o eth+ -p tcp --dport 443 -j ACCEPT            # Telegram/WhatsApp alerts