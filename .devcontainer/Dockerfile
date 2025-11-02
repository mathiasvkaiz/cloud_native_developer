# syntax=docker/dockerfile:1
FROM mcr.microsoft.com/devcontainers/base:bookworm

ARG DEBIAN_FRONTEND=noninteractive

# Install system dependencies and CLI tooling
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        gnupg \
        lsb-release \
        ca-certificates \
        unzip \
        jq \
        bash-completion \
    && rm -rf /var/lib/apt/lists/*

ENV SHELL=/bin/bash
