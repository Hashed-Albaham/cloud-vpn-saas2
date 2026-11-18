FROM alpine:3.20
RUN apk add --no-cache xl2tpd ppp iproute2 util-linux kmod
COPY xl2tpd.conf /etc/xl2tpd/xl2tpd.conf
COPY options.xl2tpd /etc/ppp/options.xl2tpd
COPY ip-up /etc/ppp/ip-up
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /etc/ppp/ip-up /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
