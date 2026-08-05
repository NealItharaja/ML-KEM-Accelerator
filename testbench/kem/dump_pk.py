#!/usr/bin/env python3
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import mlkem_ref

d = bytes(range(32))
z = bytes(255 - i for i in range(32))
m = bytes((i * 3) & 0xFF for i in range(32))
pk, sk = mlkem_ref.keygen(d, z, 512)
print("PK0", pk[:16].hex())
print("PK100", f"{pk[100]:02x}")
print("PK200", f"{pk[200]:02x}")
print("PK400", f"{pk[400]:02x}")
print("PK768", pk[768:784].hex())
print("PK799", f"{pk[799]:02x}")
print("HPK", mlkem_ref.H(pk).hex())
print("PKLEN", len(pk))
ct, ss = mlkem_ref.encaps(pk, m, 512)
print("SS ", ss.hex())
