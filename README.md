# ML-KEM Hardware Accelerator

This is an ASIC implementation (synthesizable with [Librelane](https://fossi-foundation.org/librelane/)) of the ML-KEM cryptographic primitive, formerly Kyber, standardized by NIST as part of the PQC (Post-Quantum Cryptography) toolset.

The tests and synthesis can be replicated through docker:\
`docker-compose up -d --build`<br>
`docker exec -it mlkem-dev bash`

Alternatively, the tools needed to replicate the results locally are:
* Icarus Verilog
* Librelane
  * Nix (required to run Librelane syntheis)

In order to run the tests / synthesis the following commands can be used:\
`make all`<br>
`make synth`

The former will run every test within testbench while the latter will run synthesis (Note: individual tests for specific modules can be run, see Makefile for details)

## Implementation Details
A few things to note within this implementation of ML-KEM:
1. The NTT (Number Theoretic Transform) employs the radix-2 Cooley-Tukey algorithm for efficient polynomial multiplication
2. The butterfly operations are Cooley-Tukey for forward transform, while Gentleman-Sande for the inverse transform
3. For efficient modular multiplication, the Montogomery Reduction algorithm is used instead of Barett Reduction
