# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

`pocketbase-docker` produces **unofficial multi-arch container images for
[PocketBase](https://github.com/pocketbase/pocketbase)**, which ships release binaries
but no official image. This repo builds **no application code of its own** — it
repackages the official upstream release binary into a container and publishes it to
GHCR (`ghcr.io/techrick/pocketbase-docker`).

It is a separate repo from the user's PocketBase fork (`techrick/pocketbase`). The fork
also briefly carried a Docker setup, but this standalone repo is the canonical one for
images; the fork is left untouched.

## Files (the whole repo)

- `Dockerfile` — two stages. A `fetch` stage (`FROM --platform=$BUILDPLATFORM alpine`)
  downloads `pocketbase_<VERSION>_linux_<arch>.zip` from the matching upstream GitHub
  release and unzips it; an `alpine` runtime stage copies the binary in. `VERSION`
  comes in as a build-arg (without leading `v`). Arch is selected from buildx's
  `TARGETARCH`/`TARGETVARIANT` (`amd64`/`arm64`/`armv7`).
- `.github/workflows/docker.yaml` — reusable single-version build (`workflow_call`) +
  manual `workflow_dispatch`. Logs into GHCR, builds `linux/amd64,arm64,arm/v7`, pushes.
- `.github/workflows/sync.yaml` — scheduled (`0 3 * * *`) + manual. `detect` job lists
  upstream releases via `gh api`, picks build candidates and the newest version, then a
  matrix `build` job calls `docker.yaml` per missing version.
- `README.md` — user-facing usage/setup.

## Commands

```sh
# Validate workflow YAML locally (python has yaml; jq is NOT installed locally)
python -c "import yaml; yaml.safe_load(open('.github/workflows/sync.yaml'))"

# Build one version locally (multi-arch needs buildx + QEMU)
docker build --build-arg VERSION=0.39.0 -t pb-local .
docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 --build-arg VERSION=0.39.0 .

# Manually trigger a build / sync
gh workflow run docker.yaml -R techrick/pocketbase-docker -f tag=v0.39.0 -f latest=true
gh workflow run sync.yaml   -R techrick/pocketbase-docker -f limit=25

# Inspect what's published (gh token lacks read:packages; use the registry directly)
echo "$(gh auth token)" | docker login ghcr.io -u techrick --password-stdin
docker buildx imagetools inspect ghcr.io/techrick/pocketbase-docker:0.39.0
```

## Key design decisions (and why)

- **Download the upstream binary, don't build from source.** The user's fork's synced
  tags point at *upstream* commits that don't contain a Dockerfile, and the fork
  release is a draft. PocketBase publishes per-arch release binaries, so downloading
  them is simpler, faster, and byte-identical to upstream. The Dockerfile lives on the
  default branch and takes `VERSION` as a build-arg — **do not `actions/checkout` a
  tag** (the tag's tree has no Dockerfile).
- **Cross-arch via the `fetch` stage, not emulation.** Running it on
  `$BUILDPLATFORM` and downloading the target-arch zip avoids QEMU-emulated work; only
  `apk add` in the runtime layer runs per-arch.
- **`:latest` = highest version by `sort -V`, not by date.** Upstream backports patches
  to old minor lines (e.g. `v0.22.x`) with recent dates; selecting by date would move
  `:latest` onto an old line. `detect` computes `newest` over *all* releases.
- **No rolling `{{major}}.{{minor}}` tag.** Under the parallel build matrix every patch
  of a minor pushed it (last-writer-wins), so e.g. `:0.38` landed on `0.38.0` instead
  of `0.38.2`. Only `:X.Y.Z` (exact) and `:latest` are produced.
- **`provenance: false`** on `build-push-action` — otherwise buildx attaches an
  attestation manifest that GHCR shows as an `unknown/unknown` "OS/Arch" entry.
- **Docker actions pinned to Node-24 majors** (`setup-qemu@v4`, `setup-buildx@v4`,
  `login@v4`, `metadata@v6`, `build-push@v7`) to avoid the Node-20 deprecation warning.
  `setup-qemu` uses `cache-image: false` to avoid binfmt-cache collisions across the
  parallel matrix.
- **Idempotent / stable digests.** `detect` skips versions whose image already exists
  (`docker manifest inspect`), so existing versions are never rebuilt. Builds are *not*
  bit-reproducible (floating alpine/apk + timestamps); this was reviewed and
  intentionally left as-is.

## Gotchas

- **First push to a new repo may not register workflows.** They can be valid and on the
  default branch yet absent from the Actions UI / `gh workflow list`. A second push that
  touches the workflow files forces indexing.
- **`jq` is not installed in the local Windows git-bash** (it *is* on the runners). Parse
  JSON locally with `python` instead.
- **The `gh` token lacks `read:packages`/`delete:packages`.** Listing/deleting GHCR
  versions via `gh api` fails; use the registry HTTP API for reads, or the GHCR web UI
  (Package settings) for deletes.
- **The GHCR "credentials stored unencrypted" warning** from `docker login` in the
  `detect` job is benign on an ephemeral runner — ignore it.
- **Stale rolling minor tags** (`0.22`, `0.30`, …) may still exist in GHCR from before
  the rolling tag was dropped; they're no longer updated. Delete them in the UI if
  desired — exact `:X.Y.Z` tags and `:latest` remain correct.

## Conventions

- Commit/push **directly to `master`** (no branch/PR) for this repo.
- Keep the repo tiny and source-free: only the Dockerfile, the two workflows, and docs.
