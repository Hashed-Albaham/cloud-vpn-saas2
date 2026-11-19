# cloud-vpn-saas

L2TP (MikroTik v6) -> WireGuard (phones) bridge for Coolify. One isolated network per customer.

    gateway/   shared L2TP server on UDP 1701  -> deploy ONCE
    customer/  one Coolify resource per customer (vpn + Uptime Kuma), registers itself

## 1) Upload to GitHub
Repo ROOT must contain the folders `gateway/` and `customer/` (not a parent folder).

## 2) Gateway (once)
Coolify > New Resource > your repo > Build Pack: **Docker Compose**
- Base directory: `/gateway`
- Docker compose location: `/docker-compose.yml`   (yml, not yaml)
- Remove any auto-generated domain (the gateway has no web UI). Deploy.
- Open the gateway Logs: xl2tpd must be running. Lines `[ip-up] ...` appear when routers connect.

## 3) Each customer
1. Cloudflare: A record  client1.domain.com -> server IP, **DNS only**.
2. Open UDP 1701 and the customer's WG_PORT in the server/provider firewall (if any).
3. Coolify > New Resource > same repo > Docker Compose
   - Base directory: `/customer`, compose location: `/docker-compose.yml`
   - Remove any auto-generated domain.
4. Environment Variables:

| Variable | Example | Notes |
|---|---|---|
| TENANT_ID | client1 | unique, a-z 0-9 - |
| DOMAIN | client1.domain.com | dashboard + WireGuard endpoint |
| WG_PORT | 51821 | unique per customer |
| SERVER_HOST | 164.68.105.75 | server IP/domain the router dials (same for all) |
| LAN_RANGES | 192.168.216.0/24 | the customer's real LAN(s); default is all private ranges |
| CLIENTS | phone1,tech1 | WireGuard users (default `admin`) |
| MAX_CLIENTS | 3 | 3 basic / 10 pro |

5. Deploy, then open the `vpn` service Logs:
   - the **MikroTik script** is printed -> paste the lines in the router terminal
   - a **WireGuard config** per name in CLIENTS -> save as `name.conf` and import in the WireGuard app
6. Add/remove phone users: edit CLIENTS and Redeploy.
7. Dashboard: https://client1.domain.com (create the Kuma admin immediately).

## Check
- Router: `/interface l2tp-client print` shows R, then `/ping 169.254.255.1 count=3`
- `vpn` logs `[diag]` blocks: ppp interface UP with 169.254.255.1, routes in table 100.
- Gateway logs: `[ip-up] tenant=... moved ...`

## Suspend / resume
Stop the customer's stack = suspended. Start = resumed (password and WireGuard keys are kept in volumes).

## Isolation notes
- Each customer = own network namespace; overlapping LAN ranges (even 10.0.0.0/8) are allowed:
  customer ranges are routed by policy to the tunnel and never to Docker networks.
- Nothing from the tunnel can reach the internet or Docker networks (iptables default deny).
- WireGuard clients use 198.19.254.0/24 (override with WG_SUBNET).

## Known limits
- L2TP without IPsec: the tunnel is not encrypted. Add IPsec before production.
- Kuma = ping/port monitoring. MAC discovery needs the MikroTik API (not included).
- Gateway is privileged + pid:host (trusted component). Customer containers write the shared chap-secrets.
- Other containers on the shared Coolify network can reach a customer's Kuma login (port 3001).
- IPv6 is not filtered (Docker IPv6 is off by default).
