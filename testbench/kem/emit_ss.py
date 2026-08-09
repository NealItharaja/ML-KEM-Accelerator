#!/usr/bin/env python3
# Emit expected SS hex for TB from fixed coins
import os, sys
from mlkem_ref import keygen, encaps, decaps

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

d = bytes(range(32))
z = bytes([255 - i for i in range(32)])
m = bytes([(i * 3) & 0xFF for i in range(32)])

for level in (512, 768, 1024):
    pk, sk = keygen(d, z, level)
    ct, ss = encaps(pk, m, level)
    assert decaps(sk, ct, level) == ss
    print(f"LEVEL{level}_SS={ss.hex()}")
    print(f"LEVEL{level}_PK_LEN={len(pk)}")
    print(f"LEVEL{level}_SK_LEN={len(sk)}")
    print(f"LEVEL{level}_CT_LEN={len(ct)}")
