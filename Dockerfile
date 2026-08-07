FROM nixos/nix:latest

RUN mkdir -p /etc/nix && \
    echo "sandbox = false" >> /etc/nix/nix.conf && \
    echo "filter-syscalls = false" >> /etc/nix/nix.conf

RUN nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs && \
    nix-channel --update

RUN nix-env -e git git-minimal || true

# Install dependencies & cachix
RUN nix-env -iA \
    nixpkgs.python3 \
    nixpkgs.git \
    nixpkgs.gcc \
    nixpkgs.gnumake \
    nixpkgs.iverilog \
    nixpkgs.gtkwave \
    nixpkgs.vim \
    nixpkgs.cachix

RUN cachix use openlane

WORKDIR /opt

# Clone LibreLane
RUN git clone https://github.com/librelane/librelane.git /opt/librelane

# Pre-fetch Nix dependencies
WORKDIR /opt/librelane
RUN nix-shell shell.nix --command "echo 'EDA Tools Cached!'"

WORKDIR /workspace

CMD ["/bin/sh"]