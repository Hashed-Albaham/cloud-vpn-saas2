FROM alpine:3.20
RUN apk add --no-cache wireguard-tools iptables iproute2
RUN apk add --no-cache libqrencode-tools || true
RUN command -v qrencode >/dev/null || (printf '#!/bin/sh\nexit 0\n' > /usr/local/bin/qrencode && chmod +x /usr/local/bin/qrencode)
COPY entrypoint.sh /entrypoint.sh
COPY firewall.sh /firewall.sh
COPY wg-client.sh /usr/local/bin/wg-client
RUN chmod +x /entrypoint.sh /firewall.sh /usr/local/bin/wg-client
ENTRYPOINT ["/entrypoint.sh"]
