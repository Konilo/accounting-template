FROM mcr.microsoft.com/devcontainers/base:jammy

# Also used by the CI
ARG HLEDGER_VERSION=1.52.4
ARG JUST_VERSION=1.58.0

RUN curl -sL https://github.com/simonmichael/hledger/releases/download/${HLEDGER_VERSION}/hledger-linux-x64.tar.gz \
    | tar -xzv -f- -C/usr/local/bin hledger hledger-ui hledger-web

# To query CSVs with SQL
RUN apt update && apt install -y sqlite3

# just
RUN curl -sL https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-x86_64-unknown-linux-musl.tar.gz \
    | tar -xz -f- -C/usr/local/bin just

# pdftotext
RUN apt update && apt install -y poppler-utils

# Shell script linter (for just lint)
RUN apt update && apt install -y shellcheck

# uv for Python scripting
# https://docs.astral.sh/uv/reference/installer/#changing-the-installation-path
RUN curl -LsSf https://astral.sh/uv/install.sh \
    | env UV_INSTALL_DIR="/usr/local/bin/" \
    sh

# Paisa and its dependencies (webkit2gtk for GUI)
RUN apt update \
    && apt install -y libwebkit2gtk-4.0-37 \
    && wget https://github.com/ananthakumaran/paisa/releases/download/v0.7.6/paisa-app-linux-amd64.deb \
    && apt install -y ./paisa-app-linux-amd64.deb \
    && rm paisa-app-linux-amd64.deb

# libxml2 libxslt required for the pricehist py lib
# https://lxml.de/installation.html
RUN apt update \
    && apt install -y libxml2-dev libxslt-dev

# Owned by vscode: Docker copies this into the empty claude-config volume
# on its first mount (otherwise root-owned, and Claude Code cannot log in)
RUN mkdir -p /home/vscode/.claude && chown vscode:vscode /home/vscode/.claude
