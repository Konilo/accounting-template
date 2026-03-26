FROM mcr.microsoft.com/devcontainers/base:jammy

RUN curl -sL https://github.com/simonmichael/hledger/releases/download/1.51.1/hledger-linux-x64.tar.gz \
    | tar -xzv -f- -C/usr/local/bin hledger hledger-ui hledger-web

# To query CSVs with SQL
RUN apt update && apt install sqlite3

# uv for Python scripting
# https://docs.astral.sh/uv/reference/installer/#changing-the-installation-path
RUN curl -LsSf https://astral.sh/uv/install.sh \
    | env UV_INSTALL_DIR="/usr/local/bin/" \
    sh

# Paisa and its dependencies (webkit2gtk for GUI)
RUN apt update \
    && apt install -y libwebkit2gtk-4.0-37 \
    && wget https://github.com/ananthakumaran/paisa/releases/download/v0.7.4/paisa-app-linux-amd64.deb \
    && apt install -y ./paisa-app-linux-amd64.deb \
    && rm paisa-app-linux-amd64.deb

# libxml2 libxslt required for the pricehist py lib
# https://lxml.de/installation.html
RUN apt update \
    && apt install -y libxml2-dev libxslt-dev
