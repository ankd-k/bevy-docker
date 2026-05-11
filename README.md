# bevy-docker

Pre-built Docker image for [Bevy](https://bevyengine.org/) CI pipelines. Eliminates the cost of installing Linux system packages and compiling Bevy's dependency tree on every CI run.

**Image**: `ghcr.io/ankd-k/bevy-docker:latest` (public, no auth required)

## Usage

Use this image as a container in your GitHub Actions workflow:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  ci:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/ankd-k/bevy-docker:latest
    steps:
      - uses: actions/checkout@v6
      - run: cargo fmt --check
      - run: cargo clippy -- -D warnings
      - run: cargo test
```

## What's included

- Ubuntu 24.04 with all [Bevy Linux system packages](https://bevyengine.org/learn/quick-start/getting-started/setup/#linux) pre-installed
- Rust stable toolchain + `clippy` + `rustfmt`
- [mold linker](https://github.com/rui314/mold) configured as default (reduces link time ~10× vs GNU ld)
- Bevy dependencies pre-compiled via [cargo-chef](https://github.com/lukemathwalker/cargo-chef)

## How it works

The Dockerfile uses a four-stage build:

1. **chef** — base image with system packages, Rust, cargo-chef, and mold
2. **planner** — generates `recipe.json` (a snapshot of the dependency graph); cached as long as `Cargo.toml`/`Cargo.lock` don't change
3. **cacher** — precompiles all Bevy dependencies with BuildKit cache mounts for the cargo registry; the compiled artifacts are baked into the layer
4. **final** — copies compiled artifacts and sets `BEVY_PRECOMPILE_TARGET=/deps/target`

The image is automatically rebuilt and pushed to GHCR when `Dockerfile`, `Cargo.toml`, or `Cargo.lock` change on `main`.

## Image tags

| Tag | Description |
|-----|-------------|
| `:latest` | Always points to the latest Bevy version |
| `:bevy-X.Y.Z` | Pinned to a specific Bevy version |
| `:COMMIT_SHA` | Pinned to a specific build |

Use `:bevy-X.Y.Z` if your project is not on the latest Bevy version:

```yaml
container:
  image: ghcr.io/ankd-k/bevy-docker:bevy-0.18.1
```

## Updating Bevy version

Bevy version updates are handled automatically via Dependabot. When a new Bevy release is published to crates.io, a pull request is opened, CI validates the build, and the PR is merged automatically.

## Notes

- The mold linker config lives in `/root/.cargo/config.toml` inside the image. If your project has its own `.cargo/config.toml` with `rustflags`, it will override this setting.
- Currently supports `linux/amd64` only.
