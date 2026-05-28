# pocketbase-docker

Unofficial container images for [PocketBase](https://github.com/pocketbase/pocketbase),
which doesn't ship an official image. This repo **repackages the official upstream
release binaries** — it builds no code of its own.

A daily workflow checks the upstream Releases API and publishes an image for every
recent version that doesn't have one yet, to **GitHub Container Registry (GHCR)**.

## Usage

```sh
docker run -p 8090:8090 -v "$PWD/pb_data:/pb/pb_data" ghcr.io/techrick/pocketbase-docker:latest
```

- Admin UI: <http://localhost:8090/_/>
- Data is persisted in the `/pb/pb_data` volume.
- Tags: `:latest`, `:X.Y.Z` (e.g. `:0.39.0`) and `:X.Y`.
- Architectures: `linux/amd64`, `linux/arm64`, `linux/arm/v7`.

## How it works

- **`Dockerfile`** — downloads `pocketbase_<version>_linux_<arch>.zip` from the
  upstream release matching the build-arg `VERSION` and packs the binary into a
  minimal Alpine image. The download runs on the build host (no emulation); only
  the tiny runtime layer is per-arch.
- **`.github/workflows/sync.yaml`** — scheduled daily (`0 3 * * *`). Lists the
  newest upstream releases (non-draft, non-prerelease), and for each of the latest
  `limit` versions without an image, calls the build. `:latest` is applied only to
  the newest version. Run it manually via **Actions → sync → Run workflow**
  (input `limit` controls how far back to backfill).
- **`.github/workflows/docker.yaml`** — reusable build for one version; also runnable
  manually for a specific `tag` (e.g. to rebuild `v0.20.0`).

## One-time setup

1. **Actions → enable** for this repo.
2. **Settings → Actions → General → Workflow permissions → Read and write**.
3. Run **sync** once manually to backfill the latest versions.
4. The first GHCR package is private — make it public via
   **Package → Settings → Visibility** if desired.