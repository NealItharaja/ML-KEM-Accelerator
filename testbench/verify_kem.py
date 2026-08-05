#!/usr/bin/env python3
"""
Hardware Verification Helper for ML-KEM Top Module (kem.v).

Computes golden test vectors and shared secrets (SS) for ML-KEM-512, 768, and 1024
matching testbench/test_kem.v hardware configuration.

Usage:
  python testbench/verify_kem.py --all
  python testbench/verify_kem.py --level 512
"""

import sys
from pathlib import Path

# Add repo root and testbench/kem to sys.path
REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "testbench" / "kem"))

import mlkem_ref

def get_default_coins():
    d = bytes([i for i in range(32)])
    z = bytes([255 - i for i in range(32)])
    m = bytes([(i * 3) & 0xFF for i in range(32)])
    return d, z, m

def run_verification(level: int):
    print("=" * 64)
    print(f"  ML-KEM-{level} Golden Reference Verification")
    print("=" * 64)
    
    d, z, m = get_default_coins()
    print(f"d_seed (hex) = {d.hex()}")
    print(f"z_seed (hex) = {z.hex()}")
    print(f"m_msg  (hex) = {m.hex()}")
    
    pk, sk = mlkem_ref.keygen(d, z, level)
    ct, ss = mlkem_ref.encaps(pk, m, level)
    ss_dec = mlkem_ref.decaps(sk, ct, level)
    
    assert ss == ss_dec, f"ML-KEM-{level} decaps mismatch in reference!"
    
    print("-" * 64)
    print(f"PK Length  : {len(pk)} bytes")
    print(f"SK Length  : {len(sk)} bytes")
    print(f"CT Length  : {len(ct)} bytes")
    print(f"SS (BigEnd): {ss.hex()}")
    print(f"SS (Little): {ss[::-1].hex()}")
    print("-" * 64)
    print(f"PASS: ML-KEM-{level} roundtrip verified.")
    print()
    return ss

def main():
    import argparse
    parser = argparse.ArgumentParser(description="ML-KEM Golden Verifier")
    parser.add_argument("--level", type=int, choices=[512, 768, 1024], help="ML-KEM level to verify")
    parser.add_argument("--all", action="store_true", help="Verify all levels (512, 768, 1024)")
    args = parser.parse_args()

    if args.all or (args.level is None):
        print("Verifying all ML-KEM parameter sets...\n")
        for lvl in (512, 768, 1024):
            run_verification(lvl)
    else:
        run_verification(args.level)

if __name__ == "__main__":
    main()
