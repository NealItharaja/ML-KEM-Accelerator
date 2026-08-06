FROM nixos/nix:latest

RUN nix-channel --update

# Uninstall the pre-packaged minimal git to avoid file collisions
RUN nix-env -e git git-minimal || true

# Install the requested packages
RUN nix-env -iA \
    nixpkgs.python3 \
    nixpkgs.git \
    nixpkgs.gcc \
    nixpkgs.gnumake \
    nixpkgs.iverilog \
    nixpkgs.gtkwave \
    nixpkgs.vim

WORKDIR /workspace

CMD ["/bin/sh"]