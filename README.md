# BTC Docker Stack

Bitcoin Core + Fulcrum SPV server with Tor and optional VPN support. Multi-arch — works on Intel Mac, Apple Silicon, Raspberry Pi, x86_64 PCs.

Self-contained and portable — put this directory on any machine with Docker and run.

## Architecture

| Container | Base | Purpose |
|-----------|------|---------|
| `btc-tor` | Ubuntu + obfs4 (built locally) | Tor SOCKS5 proxy with bridge support |
| `btc-node` | Ubuntu + official Bitcoin Core binary (built locally) | Bitcoin Core (non-listening, txindex enabled) |
| `btc-fulcrum` | Author's image (`cculianu/fulcrum`) | Fulcrum Electrum server — your wallet connects here |
| `btc-vpn` | linuxserver/wireguard (optional) | WireGuard VPN tunnel |
| `btc-vpn-proxy` | Ubuntu + microsocks (optional, built locally) | SOCKS5 proxy through VPN for clearnet mode |

Bitcoin Core is downloaded directly from `bitcoincore.org` and SHA256 verified during build.

## Network modes

| Mode | Command | Chain | Use case |
|------|---------|-------|----------|
| Tor onion only | `./btc.sh tor on` | Bitcoin → Tor → Internet | Max privacy, onion peers only |
| Tor mixed | `./btc.sh tor mixed` | Bitcoin → Tor → Internet | Onion + clearnet peers through Tor |
| VPN + Tor | `./btc.sh vpn on` | Bitcoin → Tor → VPN → Internet | ISP sees VPN only, peers see onion |
| VPN + Tor mixed | `./btc.sh tor mixed` (with VPN on) | Bitcoin → Tor → VPN → Internet | Most peers, all traffic hidden |
| VPN only | `./btc.sh tor off` (with VPN on) | Bitcoin → VPN → Internet | Fast sync, IP hidden by VPN |
| Direct | `./btc.sh tor off` (no VPN) | Bitcoin → Internet | Fastest, real IP exposed |

## Security

- **Non-listening**: `listen=0` — node only makes outbound connections. Nobody can connect to it.
- **RPC locked down**: Uses `rpcauth` (salted HMAC hash). Only accessible from the Docker network (`172.28.0.0/16`). No RPC port exposed to host.
- **Fulcrum localhost only**: All Fulcrum ports bound to `127.0.0.1` — Electrum (50001), admin RPC (8000), stats HTTP (8080).
- **No IP logging**: `logips=0` in Bitcoin config.
- **Verified binaries**: Bitcoin Core binary checksum verified against official SHA256SUMS during Docker build.
- **Tor bridges**: obfs4 pluggable transports bypass ISP/firewall Tor blocking.

## Setup

### 1. Copy sample configs and generate credentials

```bash
cp bitcoin.conf.sample bitcoin.conf
cp fulcrum.conf.sample fulcrum.conf
python3 rpcauth.py btcrpc
```

Paste the **rpcauth line** into `bitcoin.conf` and the **password** into `fulcrum.conf`.

### 2. Configure Docker Desktop for auto-start

Docker Desktop > Settings > General > **Start Docker Desktop when you sign in to your computer**

### 3. Start the stack

```bash
./btc.sh up
```

### 4. (Optional) Enable VPN

Place your WireGuard config at `vpn/wg0.conf`. Before using it, remove all IPv6 lines:

- Remove the IPv6 address from `Address` (e.g. `,fc00:bbbb:...`)
- Remove `,::/0` or `,::0/0` from `AllowedIPs`

Example clean config:

```ini
[Interface]
PrivateKey = <your key>
Address = 10.x.x.x/32
DNS = 100.64.0.63

[Peer]
PublicKey = <peer key>
AllowedIPs = 0.0.0.0/0
Endpoint = <server>:51820
```

**Older Docker kernels:** If VPN fails with `nft` errors, add these lines to the `[Interface]` section:

```ini
Table = off
PostUp = GATEWAY=$(ip route | grep default | awk '{print $3}'); ip route add <endpoint-ip>/32 via $GATEWAY; ip route replace default dev %i
PreDown = ip route delete <endpoint-ip>/32; ip route delete default dev %i
```

Replace `<endpoint-ip>` with your WireGuard server IP.

Then:

```bash
./btc.sh vpn on
```

## Commands

All commands go through `./btc.sh`:

```
Bitcoin:
  info      Node info (sync progress, version, peers)
  net       Network/peer overview
  peers     Detailed peer info
  block     Blockchain info
  log       Tail Bitcoin logs
  debug     Tail debug.log
  cli <cmd> Run any bitcoin-cli command

Fulcrum:
  fulc      Fulcrum server info
  fulclog   Tail Fulcrum logs
  clients   Connected wallet clients
  query <a> Query an address
  stats     Open stats dashboard in browser

Tor & VPN:
  torstatus Tor bootstrap progress (0-100%)
  torlog    Tail Tor logs
  vpnlog    Tail VPN logs
  tor <on|mixed|off>  Toggle Tor (on=onion only, mixed=both)
  vpn <on|off>  Toggle VPN (requires vpn/wg0.conf)
  myip      Check exit IP (verify VPN/Tor is working)
  speedtest Run speedtest through VPN/network
  mode      Show current Tor/VPN status

Stack:
  up        Start all containers
  down      Stop all containers
  nuke      Stop and remove all images
  status    Container status
  logs      Tail all logs
  update    Update images (optional: version arg)
```

## Connect your wallet

```
127.0.0.1:50001
```

Fulcrum only listens on localhost — not accessible from the network.

## Updating

```bash
# Rebuild all with current versions
./btc.sh update

# Upgrade Bitcoin Core to a specific version
./btc.sh update 32.0
```

## Stopping and cleanup

```bash
# Stop all containers
./btc.sh down

# Stop and remove all images (full cleanup)
./btc.sh nuke
```

Blockchain data in `data/` is preserved in both cases.

## Portable usage

The entire stack is self-contained. To run on a different machine:

1. Copy (or clone) this directory to the target machine
2. `cp bitcoin.conf.sample bitcoin.conf && cp fulcrum.conf.sample fulcrum.conf`
3. Generate and paste RPC credentials
4. `./btc.sh up`

Config files are portable across platforms. Blockchain data in `data/` can be re-synced on the new machine.

## Initial sync

- Tor sync is slow — expect days to weeks for full chain.
- VPN clearnet sync is much faster.
- `dbcache=4096` in `bitcoin.conf` speeds up initial sync (uses ~4GB RAM).
- After sync completes, lower `dbcache` to `1024` to free RAM for Fulcrum.
- Fulcrum begins its own indexing only after Bitcoin is fully synced (takes additional hours).

## Directory structure

```
BTCDocker/
├── btc.sh                    # Main command interface
├── docker-compose.yml        # Base container orchestration
├── docker-compose.vpn.yml    # VPN overlay (used when VPN is on)
├── bitcoin/Dockerfile        # Bitcoin Core (Ubuntu + official binary, multi-arch)
├── bitcoin.conf.sample       # Bitcoin config template
├── tor/Dockerfile            # Tor proxy with obfs4 bridges (Ubuntu, multi-arch)
├── tor/torrc                 # Tor configuration
├── fulcrum.conf.sample       # Fulcrum config template
├── vpn-proxy/Dockerfile      # SOCKS proxy for VPN clearnet mode (Ubuntu, multi-arch)
├── .env                      # Data directory paths
├── btc-cli.sh                # Bitcoin CLI wrapper
├── fulcrum-admin.sh          # Fulcrum admin wrapper
├── update.sh                 # Manual update script (accepts version arg)
├── toggle-tor.sh             # Toggle Tor on/off
├── toggle-vpn.sh             # Toggle VPN on/off
├── rpcauth.py                # RPC credential generator
├── vpn/                      # Place wg0.conf here (gitignored)
└── data/                     # Created automatically (gitignored)
    ├── btc/                  # Bitcoin blockchain (~600GB+)
    └── fulcrum/              # Fulcrum index (~100GB+)
```

## Roadmap

- **Lightning Network** — LND or Core Lightning container, connects to the local Bitcoin node. Enables instant BTC payments via payment channels. Tor hidden service for inbound channel connections without exposing real IP.
- **Business payments** — BTCPay Server (self-hosted payment processor, replaces Stripe/PayPal) + LNbits (multi-wallet, per-store accounts, invoicing, extensions) on top of LND. Full sovereign payment stack.
