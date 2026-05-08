# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Does

`bevy-docker` produces a pre-built Docker image (`ghcr.io/ankd-k/bevy-docker`) that consuming Bevy projects use as a CI container to skip slow dependency compilation. It is not a runnable application — `src/main.rs` is an empty placeholder required by cargo-chef.

## Building the Image

```bash
# Requires BuildKit (DOCKER_BUILDKIT=1 is implicit with buildx)
docker buildx build -t bevy-docker .
```

CI pushes automatically when `Dockerfile`, `Cargo.toml`, or `Cargo.lock` change on `main` (see `.github/workflows/build.yml`).

## Dockerfile Architecture

Four-stage build:

1. **chef** — Ubuntu 24.04 + all Bevy system packages + Rust toolchain + `cargo-chef` + `mold`
2. **planner** — runs `cargo chef prepare` to produce `recipe.json` (invalidated only when `Cargo.toml`/`Cargo.lock` change)
3. **cacher** — runs `cargo chef cook --release` with BuildKit cache mounts (`~/.cargo/registry`, `~/.cargo/git`) to precompile all Bevy dependencies
4. **final** — copies compiled artifacts (`/deps/target`) and cargo registry (`~/.cargo/registry`) for consuming containers

The mold linker is configured in `.cargo/config.toml` via `rustflags = ["-C", "link-arg=-fuse-ld=mold"]`.

## How Consuming Projects Use This Image

```yaml
jobs:
  ci:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/ankd-k/bevy-docker:latest
    steps:
      - uses: actions/checkout@v4
      - run: cargo check
```

## Cargo.toml Conventions

- Package name matches repo name (`bevy-docker`)
- Omit optional Bevy feature flags — keep the dependency minimal so the cached layers stay broadly applicable
- `[profile.dev.package."*"]` sets `opt-level = 3` so precompiled deps run fast even in dev builds

## Key Design Decisions

- **cargo-chef**: Separates dependency compilation from source compilation so Docker layer cache survives source-only changes.
- **BuildKit cache mounts** (`--mount=type=cache,sharing=locked`): Persists the cargo registry across builds without baking it into image layers.
- **mold linker**: Reduces link time ~10× compared to GNU ld; configured globally so consuming projects get the benefit automatically.

## Documentation

Design documentation is in `docs/design-doc.md` (written in Japanese).
