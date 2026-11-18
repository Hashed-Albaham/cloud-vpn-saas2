# cloud-vpn-saas

Multi-tenant L2TP (MikroTik v6) -> WireGuard (phones) bridge for Coolify.
Each customer = isolated network namespace, no internet egress through the tunnel.

    gateway/   shared L2TP server (deploy ONCE)
    customer/  one stack per customer (vpn + Uptime Kuma), auto-registers itself

## Host prerequisites
None via terminal: the gateway loads ppp modules itself and Docker creates /data/l2tp-gateway.
Only if the server has a firewall (ufw / provider panel): open UDP 1701 and every customer's WG_PORT.

## Deploy
1. Coolify > New Resource > Git repo (this one) > Build Pack **Docker Compose**
   - Base Directory: `/gateway`  -> Deploy (once)
2. For every customer: New Resource > same repo > Base Directory `/customer`
   Variables:
   - TENANT_ID   client1 (a-z 0-9 -, unique)
   - DOMAIN      client1.domain.com (Cloudflare DNS-only)
   - WG_PORT     51821 (unique per customer)
   - SERVER_HOST server IP/domain the router dials for L2TP
   Optional: LAN_RANGES, MAX_CLIENTS (3/10), WG_SUBNET
   -> Deploy. The MikroTik script is printed in the `vpn` logs (also /data/mikrotik.rsc).
3. Phones: set `CLIENTS=phone1,phone2` (default `admin`), redeploy. Configs + QR are printed in the
   `vpn` logs. Add/remove a user = edit CLIENTS and Redeploy (limit = MAX_CLIENTS).

## Lifecycle
Stop stack = suspended (router can't attach). Start = resumed, keys/password kept in volume.

## Notes
- L2TP has no IPsec yet: tunnel is unencrypted. Add IPsec before production.
- MAC auto-discovery needs MikroTik API; Kuma does ping monitoring only.
- Gateway is privileged + pid:host (trusted component). Customer containers write the shared chap-secrets.
- Basic plan: delete the `kuma` block in customer/docker-compose.yml.
