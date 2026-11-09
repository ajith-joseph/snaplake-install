# Install Snaplake

Snaplake installs a complete data platform onto a Linux node: Kubernetes (k3s), storage, the lakehouse catalog, SQL and
notebooks, all in one run.

## 1. Install the CLI

On the machine you install from (Linux x86-64; Ubuntu 22.04+, Debian 12+ or RHEL/Rocky/Alma 9+):

```shell
curl -fsSL https://raw.githubusercontent.com/ajith-joseph/snaplake-install/main/install.sh | sh
```

This downloads the latest `snaplake` binary, checks its checksum and puts it in `/usr/local/bin` (or `~/.local/bin`
when that isn't writable). Nothing else on the machine is changed.

Options, set before `sh`:

| Variable | Default | |
|---|---|---|
| `SNAPLAKE_VERSION` | `latest` | A release tag, e.g. `v0.21.0` |
| `SNAPLAKE_INSTALL_DIR` | `/usr/local/bin` or `~/.local/bin` | Where the binary goes |

For example: `curl -fsSL .../install.sh | SNAPLAKE_VERSION=v0.21.0 sh`

## 2. Install the platform

```shell
snaplake init       # writes datalake-package-install.yml in this directory
                    # edit it: the node's address and SSH user, your platform domain, the MetalLB addresses
snaplake doctor     # checks SSH and sudo on the node and the CLI itself; changes nothing
snaplake install    # installs the platform
```

`snaplake --help` lists every command.

## What you need

- **The node**: Ubuntu/Debian or a RHEL-family distribution, x86-64, a user with passwordless `sudo` reachable over SSH
  from this machine. The smallest size is proven on 12 cores and 30 GB of RAM, with about 150 GB free under `/var`.
- **Addresses**: a few free addresses on the node's subnet for the platform's load balancer, and a DNS domain whose
  names point at one of them.
- **Internet access** for the node and this machine, or an offline package for airgapped sites.

---

This repository only serves the installer. Each Snaplake release updates it.
