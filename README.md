# ImmortalWrt Production Firmware Build System

Docker-based build pipeline for x86_64 ImmortalWrt firmware.
Produces two flavors:
- **main-router**: full router with WAN/PPPoE/firewall/UPnP
- **bypass-gateway**: lean transparent-proxy gateway (no WAN)

## Layout

```
~/build/
├── docker/Dockerfile           builder image (Ubuntu 22.04 + IWrt deps)
├── configs/*.config            kernel/package selection (diffconfig)
├── files/<role>/etc/...        baked-in /etc files (uci-defaults, sysctl)
├── scripts/                    prepare / build / package
├── source/                     ImmortalWrt git tree (created on first run)
└── output/                     final firmware images
```

## Quick start

```bash
cd ~/build

# 1. Build the builder image (once)
docker build -t iwrt-builder:24.10 docker/

# 2. Fetch ImmortalWrt source + feeds (once, ~10 min)
./scripts/prepare-source.sh

# 3. Build main router firmware (~30-60 min on 4 vCPU)
./scripts/build.sh main-router

# 4. Build bypass gateway firmware
./scripts/build.sh bypass-gateway

# Output appears in ./output/<role>/
```

## Updating package selection

Edit `configs/main-router.config` or `configs/bypass-gateway.config`,
then re-run `./scripts/build.sh <role>`.

## Updating ImmortalWrt source

```bash
./scripts/prepare-source.sh --pull
```

## Security defaults baked in (uci-defaults)

- root password unset (forces first-boot setup via LuCI)
- IPv6 disabled at sysctl level (no leak)
- dropbear: PasswordAuth off, RootPasswordAuth off
- ttyd: disabled at boot (manual enable)
- UPnP: disabled at boot (manual enable)
- dnsmasq: noresolv, filter_aaaa, localservice, interface=br-lan
- LAN IP: 192.168.10.1 (main) / 192.168.10.2 (bypass) - change in uci-defaults
```
