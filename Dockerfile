# syntax=docker/dockerfile:1

# ===== Stage 1: chef =====
FROM ubuntu:24.04 AS chef

RUN apt-get update && apt-get install -y --no-install-recommends \
    g++ \
    pkg-config \
    libx11-dev \
    libasound2-dev \
    libudev-dev \
    libxkbcommon-x11-0 \
    libwayland-dev \
    libxkbcommon-dev \
    mold \
    clang \
    curl \
    git \
    ca-certificates \
    unzip \
  && rm -rf /var/lib/apt/lists/*

ARG RUST_VERSION=stable
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain ${RUST_VERSION} \
  && . /root/.cargo/env \
  && rustup component add clippy rustfmt \
  && cargo install cargo-chef --locked
ENV PATH="/root/.cargo/bin:${PATH}"

COPY .cargo/config.toml /root/.cargo/config.toml

WORKDIR /deps

# ===== Stage 2: planner =====
FROM chef AS planner
COPY Cargo.toml Cargo.lock ./
COPY src/ src/
RUN cargo chef prepare --recipe-path recipe.json

# ===== Stage 3: cacher =====
FROM chef AS cacher
COPY --from=planner /deps/recipe.json recipe.json
RUN --mount=type=cache,target=/root/.cargo/registry,sharing=locked \
    --mount=type=cache,target=/root/.cargo/git,sharing=locked \
    cargo chef cook --recipe-path recipe.json

# ===== Final image =====
FROM chef AS final
COPY --from=cacher /deps/target /deps/target
COPY --from=cacher /root/.cargo/registry /root/.cargo/registry
