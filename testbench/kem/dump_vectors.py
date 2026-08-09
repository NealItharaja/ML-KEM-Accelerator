#!/usr/bin/env python3
# Dump visible ML-KEM-512/768/1024 vectors for compare
import os, sys
from mlkem_ref import keygen, encaps, decaps

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.makedirs(os.path.join(os.path.dirname(__file__), "dumps"), exist_ok=True)

def coins():
    d = bytes([i for i in range(32)])
    z = bytes([255 - i for i in range(32)])
    m = bytes([(i * 3) & 0xFF for i in range(32)])
    return d, z, m

def main():
    d, z, m = coins()
    for level in (512, 768, 1024):
        pk, sk = keygen(d, z, level)
        ct, ss = encaps(pk, m, level)
        ss2 = decaps(sk, ct, level)
        path = os.path.join(os.path.dirname(__file__), "dumps", f"ref_{level}.txt")
        
        with open(path, "w") as f:
            f.write(f"LEVEL={level}\n")
            f.write(f"D={d.hex()}\n")
            f.write(f"Z={z.hex()}\n")
            f.write(f"M={m.hex()}\n")
            f.write(f"PK={pk.hex()}\n")
            f.write(f"SK={sk.hex()}\n")
            f.write(f"CT={ct.hex()}\n")
            f.write(f"SS={ss.hex()}\n")
            f.write(f"SS2={ss2.hex()}\n")
            f.write(f"MATCH={ss == ss2}\n")
        print(f"wrote {path} SS={ss.hex()} MATCH={ss == ss2}")


if __name__ == "__main__":
    main()
