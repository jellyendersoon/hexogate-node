# Hexogate Node

The node agent for the [Hexogate panel](https://github.com/jellyendersoon/hexogatepanel). It runs the Xray or WireGuard core on a server and lets the panel manage it over gRPC or REST.

Hexogate Node is a fork of the PasarGuard node and stays protocol-compatible with it: the gRPC service (`service.NodeService`), the REST endpoints and the reported node version are unchanged, so the panel and existing nodes keep working during a rollout.

## Install with Docker

```bash
sudo mkdir -p /var/lib/pg-node/certs
# put ssl_cert.pem and ssl_key.pem in /var/lib/pg-node/certs, then:
curl -fsSL -o docker-compose.yml https://raw.githubusercontent.com/jellyendersoon/hexogate-node/main/docker-compose.yml
# set API_KEY (any UUID) in docker-compose.yml, then:
docker compose up -d
```

The image is `ghcr.io/jellyendersoon/hexogate-node`. Data and certificates stay under `/var/lib/pg-node`, the path existing nodes already use, so a node can switch images without moving files.

## Choosing the Xray core

The image bundles an Xray build chosen at build time:

| Setting | Default | Purpose |
|---|---|---|
| `XRAY_REPO` | `XTLS/Xray-core` | GitHub repository whose releases publish `Xray-linux-<arch>.zip` |
| `XRAY_VERSION` | `latest` | Release tag to bundle, for example `v26.3.27` |

To ship your own Xray fork, set the repository variables `XRAY_REPO` and `XRAY_VERSION` in this repo's GitHub settings (Settings, Secrets and variables, Actions, Variables). The release and dev image workflows pass them to the build. Locally:

```bash
docker build --build-arg XRAY_REPO=<owner>/<xray-fork> --build-arg XRAY_VERSION=<tag> -t hexogate-node .
```

On a bare host, `scripts/install_xray.sh` installs the same way (`XRAY_REPO=... XRAY_VERSION=... sudo -E bash scripts/install_xray.sh`).

### Shipping a core that is not published as a GitHub release

If your Xray build exists only as a binary (for example the `hexogate.5` core the fleet runs today), use one of these. Both refuse to build unless the binary matches the sha256 you give.

- **Pinned URL.** Host the binary or an Xray-style zip anywhere the build can reach, then build with `--build-arg XRAY_URL=<url> --build-arg XRAY_SHA256=<sha256 of the xray binary>`. A bare binary gets its `geoip.dat`/`geosite.dat` from the regular `XRAY_REPO` release.
- **Local overlay, no upload.** On a host that already has the binary, layer it onto the published image:

  ```bash
  cp /path/to/xray-26.3.27-hexogate.5 ./xray
  docker build -f Dockerfile.local-core \
    --build-arg XRAY_SHA256="$(sha256sum ./xray | cut -d' ' -f1)" \
    -t hexogate-node:hexogate.5 .
  ```

  Point the node's compose file at `hexogate-node:hexogate.5` and drop the xray bind mount.

## Configuration

See `.env.example` for every option. Environment variable names are unchanged from upstream (`SERVICE_PORT`, `API_KEY`, `PG_NODE_WG_*` and so on) so existing compose files keep working.

## Development

```bash
make deps
make install_xray            # or: bash scripts/install_xray.sh
mkdir -p certs && make generate_server_cert && make generate_client_cert
go test ./...
```

Regenerate the gRPC code after editing `common/service.proto` with `make generate_grpc_code` (protoc 34.1, protoc-gen-go v1.36.11, protoc-gen-go-grpc v1.6.1).

## License

AGPL-3.0, inherited from the upstream project. See [LICENSE](LICENSE).
