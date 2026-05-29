# pocketbase-docker

Unofficial multi-arch container images for [PocketBase](https://github.com/pocketbase/pocketbase),
which doesn't ship an official image. This repo **repackages the official upstream
release binaries** — it builds no code of its own.

A daily workflow checks the upstream Releases API and publishes an image to
**GitHub Container Registry (GHCR)** for every recent version that doesn't have one yet.

## Usage

```sh
docker run -p 8090:8090 -v "$PWD/pb_data:/pb/pb_data" ghcr.io/techrick/pocketbase-docker:latest
```

- Admin UI: <http://localhost:8090/_/>
- Data is persisted in the `/pb/pb_data` volume (mount it to keep your data).
- The container runs `pocketbase serve --http=0.0.0.0:8090 --dir=/pb/pb_data`.

### Tags

- `:latest` — the highest released version (by **version number**, not date).
- `:X.Y.Z` — an exact version, e.g. `:0.39.0`. **Use these to pin.**

There is intentionally **no rolling `:X.Y` tag** (see [CLAUDE.md](CLAUDE.md) for why).

### Architectures

`linux/amd64`, `linux/arm64`, `linux/arm/v7` (32-bit ARM, e.g. Raspberry Pi 2/3).

## How it works

- **`Dockerfile`** — a `fetch` stage downloads `pocketbase_<VERSION>_linux_<arch>.zip`
  from the matching upstream release and unzips the binary; a minimal `alpine`
  runtime stage copies it in. The download runs natively on the build host
  (`--platform=$BUILDPLATFORM`), so there's **no QEMU-emulated compilation** — only
  the tiny runtime layer is per-arch. `VERSION` is passed as a build-arg.
- **`.github/workflows/sync.yaml`** — scheduled daily (`0 3 * * *`) and manually
  dispatchable. Lists upstream releases (non-draft, non-prerelease) via the GitHub
  API, takes the newest `limit` (by publish date, default 10) as build candidates,
  skips any that already have an image, and builds the rest via a matrix. `:latest`
  is applied only to the highest-versioned release.
- **`.github/workflows/docker.yaml`** — reusable single-version build (called by
  `sync.yaml` per version). Also runnable manually for a specific `tag` (e.g. to
  rebuild `v0.20.0`), with an optional `latest` toggle.

Existing images are never rebuilt (the `detect` step skips versions that already
have an image), so a given version's digest is stable once published.

## One-time setup

1. **Actions → enable** for this repo (forks/new repos have Actions off by default).
2. **Settings → Actions → General → Workflow permissions → Read and write**.
3. Run **sync** once manually (**Actions → sync → Run workflow**) to backfill — set
   `limit` higher to reach further back.
4. The first GHCR package is private — make it public via
   **Package → Settings → Visibility** if you want anonymous `docker pull`.

## Notes

- **Backfill scope:** `sync`'s `limit` is the number of most-recently-*published*
  releases to consider. PocketBase backports patches to old minor lines (e.g.
  `v0.22.x`) with recent dates, so a small `limit` may include old-line patches and
  exclude versions you'd expect. Raise `limit` to cover more.
- **Builds are not bit-reproducible** (floating `alpine:latest`, `apk` packages and
  build timestamps). This is intentional and harmless here — the PocketBase binary
  itself is byte-identical from upstream, and existing versions aren't rebuilt.
