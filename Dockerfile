FROM nixos/nix:latest

# 1. Disable Nix sandboxing to fix the Docker "seccomp BPF" error
RUN mkdir -p /etc/nix && \
    echo "sandbox = false" >> /etc/nix/nix.conf && \
    echo "filter-syscalls = false" >> /etc/nix/nix.conf

# 2. Explicitly add the standard NixOS channel before updating
RUN nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs && \
    nix-channel --update

# 3. Uninstall the pre-packaged minimal git to avoid file collisions
RUN nix-env -e git git-minimal || true

# 4. Install dependencies AND cachix
RUN nix-env -iA \
    nixpkgs.python3 \
    nixpkgs.git \
    nixpkgs.gcc \
    nixpkgs.gnumake \
    nixpkgs.iverilog \
    nixpkgs.gtkwave \
    nixpkgs.vim \
    nixpkgs.cachix

# 5. Set up Cachix to pull pre-compiled OpenROAD / EDA binaries
RUN cachix use openlane

WORKDIR /opt

# 6. Clone LibreLane (Replace with your actual librelane URL)
RUN git clone https://github.com/librelane/librelane.git /opt/librelane

# 7. Pre-fetch Nix dependencies so 'make synth' doesn't stall later
WORKDIR /opt/librelane
RUN nix-shell shell.nix --command "echo 'EDA Tools Cached!'"

WORKDIR /workspace

CMD ["/bin/sh"]