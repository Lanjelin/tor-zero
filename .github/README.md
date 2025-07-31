# tor-zero

A secure, zero-footprint Docker image for running Tor, optionally with the Lyrebird pluggable transport — fully rootless, distroless, and built entirely `FROM scratch` for maximum isolation and minimal attack surface.

Hosted image:\
📦 [`ghcr.io/lanjelin/tor-zero`](https://ghcr.io/lanjelin/tor-zero)

---

## 🔐 Security-First Design

This image is built with a focus on robust container hardening:

- **Built from scratch** — no shell, package manager, or system utilities.
- **Fully static binaries** — Tor and Lyrebird are compiled with all dependencies included.
- **Runs as non-root** — `USER 1000:1000` is set to reduce attack surface.
- Designed for immutable infrastructure — writable paths must be explicitly mounted.
- Minimalist by design — extremely compact image, ideal for secure deployments.

---

## 🧱 What's Inside?

- ✅ [`tor`](https://gitlab.torproject.org/tpo/core/tor) `v0.4.8.17` — statically compiled with:
  - `zlib`, `libevent`, `openssl`, `xz`, `zstd`
  - stripped binaries, no manpages, no unit tests
- ✅ [`lyrebird`](https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird) `v0.6.1`
  - Go static build with `CGO_ENABLED=0`

---

## 🚀 Usage

> 🧑 You may optionally override the container's default user (UID 1000) at runtime using the `--user` flag if your mounted directories are owned by a different UID.

Create a `torrc` configuration file locally (or in a mounted volume):

```bash
mkdir tor/
nvim tor/torrc
```

Then run:

```bash
docker run --rm \
  -v "$(pwd)/tor:/tor" \
  -p 9050:9050 \
  ghcr.io/lanjelin/tor-zero \
  -f /tor/torrc
```

The following:

- Mounts your custom Tor configuration
- Exposes a port if needed (e.g., for socks)
- Starts `tor` with the specified config file

> 💡 Lyrebird is enabled via `ClientTransportPlugin` in `torrc`. No shell or additional setup is required in the container.

---

## 🧩 Docker Compose

You can also run the container using Docker Compose:

```yaml
services:
  tor:
    image: ghcr.io/lanjelin/tor-zero
    user: "1000:1000"
    volumes:
      - ./tor:/tor
    ports:
      - "9050:9050"
    command: ["-f", "/tor/torrc"]
```

To run:

```bash
docker-compose up
```

> 📌 Ensure that `./tor` on the host includes your `torrc` and any subdirectories like `datadir`, `servicedir`, and `logdir`, all writable by UID 1000.

---

## 📁 Volumes

This image does **not** include `/etc/tor` or writable paths by default.

### Recommended approach:

Mount an external directory (e.g. `./tor`) as read-write and specify paths inside your `torrc` like this:

```torrc
DataDirectory /tor/datadir
HiddenServiceDir /tor/servicedir
Log notice file /tor/logdir/notice.log
```

Ensure that the `./tor` directory exists on the host and is writable by UID 1000.

---

## 🛠️ Build Info

This image is built in 3 stages:

1. **Builder stage (Debian)** compiles Tor and dependencies from source.
2. **Go builder stage** compiles Lyrebird.
3. **Final `scratch` stage** copies only required binaries and config, sets user, and declares entrypoint.

Everything else is excluded — no shell, no libc, no extras.

---

## 🧪 Building the Image Locally

```bash
git clone https://github.com/lanjelin/tor-zero.git
cd tor-zero
docker build -t tor-zero .
```

> 📦 This performs a multi-stage build using pinned versions of Tor, Lyrebird, and all their dependencies. The final image is based on `scratch` and includes only the compiled binaries.

---

## 📜 License

Tor and Lyrebird are licensed under their respective open source licenses. This Docker image does not modify their source code.

---

## 👤 Maintainer

**lanjelin**\
Image hosted at [ghcr.io/lanjelin/tor-zero](https://ghcr.io/lanjelin/tor-zero)

---


