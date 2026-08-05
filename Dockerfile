FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV USER=root

# 1. Install Verilog, Python, and dependencies for Nix
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    make \
    python3 \
    python3-pip \
    iverilog \
    gtkwave \
    vim \
    wget \
    curl \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Nix natively in the Docker container
RUN mkdir -m 0755 /nix && chown root /nix
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

# 3. Add Nix to PATH and enable modern features (Flakes)
ENV PATH="/root/.nix-profile/bin:$PATH"
RUN mkdir -p /etc/nix && \
    echo "experimental-features = nix-command flakes" > /etc/nix/nix.conf

WORKDIR /workspace

CMD ["/bin/bash"]