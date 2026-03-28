# discourse-bridge

A tiny Nginx reverse-proxy container for running Discourse (installed with the official `discourse_docker` method) on a host that already uses Dokploy for ingress and app routing.

This project lets you:

- keep Discourse installed in `/var/discourse` using the supported installer/workflow
- avoid binding Discourse directly to public ports `80/443`
- route traffic through Dokploy like your other apps

## Why this exists

The default Discourse install expects to own ports `80/443` on the host. On a Dokploy server, those ports are usually already managed by Dokploy's proxy stack.

This bridge solves that by using this flow:

1. Discourse container listens on host localhost port `8080` only
2. This bridge container (deployed in Dokploy) receives public traffic for your Discourse domain
3. Nginx in the bridge forwards requests to `http://172.17.0.1:8080`

## Repository contents

- `Dockerfile`: Nginx image for the bridge
- `nginx.conf`: reverse proxy config pointing at the Docker bridge gateway (`172.17.0.1:8080`), with forwarded headers and websocket support

## Recommended architecture

Internet -> Dokploy domain routing -> discourse-bridge container (port 80) -> Docker bridge gateway `172.17.0.1:8080` -> Discourse app container

This assumes the bridge container can reach the host through Docker's default bridge gateway at `172.17.0.1`.

## Step-by-step setup

## 1) Install Discourse with the official method

Use Discourse's official cloud installer documentation:

- https://github.com/discourse/discourse/blob/main/docs/INSTALL-cloud.md

On your server:

```bash
wget -qO- https://raw.githubusercontent.com/discourse/discourse_docker/main/install-discourse | sudo bash
```

If Dokploy already occupies ports `80/443`, you may need to temporarily stop the service that binds them for the initial installation/bootstrap phase.

## 2) Configure Discourse to listen on localhost only

Edit `/var/discourse/containers/app.yml` after install.

Set Discourse app port mapping to localhost only:

```yaml
expose:
  - "127.0.0.1:8080:80"
```

Set your real forum hostname in env:

```yaml
env:
  DISCOURSE_HOSTNAME: forum.example.com
```

Then rebuild Discourse:

```bash
cd /var/discourse
./launcher rebuild app
```

Notes:

- If TLS is terminated by Dokploy, keep TLS handling there and forward `X-Forwarded-Proto` correctly (already done in this repo).
- Ensure your Discourse app config does not require direct public `443` binding.
- This repo expects the host to be reachable from the bridge container at `172.17.0.1`. That is typical with Docker's default bridge network on Linux, but you should verify it on your Dokploy host.

## 3) Deploy this bridge in Dokploy

Create a new Dokploy app from this repository:

- Build source: this repo (`discourse-bridge`)
- Dockerfile path: `./Dockerfile`
- Exposed container port: `80`
- Domain: `forum.example.com` (same as `DISCOURSE_HOSTNAME`)

Important runtime setting:

- No special host mapping is required by the current Nginx config.
- The bridge expects the host-side Discourse port to be reachable at `172.17.0.1:8080`.
- If your Dokploy or Docker setup uses a different bridge gateway, update `nginx.conf` accordingly and redeploy.

## 4) DNS

Point your forum domain (for example `forum.example.com`) to your Dokploy server public IP.

## 5) Validate

Check locally on the host:

```bash
curl -I http://127.0.0.1:8080
```

Check that the bridge container can reach the host gateway:

```bash
curl -I http://172.17.0.1:8080
```

Check through Dokploy domain:

```bash
curl -I https://forum.example.com
```

## Operations

Upgrade Discourse (official workflow):

```bash
cd /var/discourse
./launcher rebuild app
```

Bridge updates:

- redeploy this Dokploy app whenever `nginx.conf` or `Dockerfile` changes

## Troubleshooting

### 502 from Dokploy

Likely causes:

- Discourse is not running on `127.0.0.1:8080`
- `172.17.0.1` is not the correct host gateway address in your Docker/Dokploy setup
- firewall/iptables rules blocking bridge container -> host gateway path

### Redirect or HTTPS loop

Check:

- Dokploy forwards `X-Forwarded-Proto: https`
- `DISCOURSE_HOSTNAME` matches your actual public domain
- only one layer is responsible for TLS termination

### Websocket issues

This repo already sets websocket headers in `nginx.conf`. If issues remain, verify upstream/proxy timeouts in Dokploy.

## Security notes

- Keep Discourse bound to localhost (`127.0.0.1`) to avoid bypassing Dokploy.
- Keep your server and Discourse updated regularly.
- Follow Discourse backup and restore recommendations.
