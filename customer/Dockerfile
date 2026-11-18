FROM alpine:3.20
RUN apk add --no-cache wireguard-tools iptables iproute2 qrencode
COPY entrypoint.sh /entrypoint.sh
COPY firewall.sh /firewall.sh
COPY wg-client.sh /usr/local/bin/wg-client
RUN chmod +x /entrypoint.sh /firewall.sh /usr/local/bin/wg-client
ENTRYPOINT ["/entrypoint.sh"]
