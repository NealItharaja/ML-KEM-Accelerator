#!/usr/bin/env python3
"""Golden SampleNTT (FIPS 203 Parse over SHAKE128)."""
import hashlib

Q = 3329


def sample_ntt(rho: bytes, i: int, j: int):
    data = hashlib.shake_128(rho + bytes([i, j])).digest(8000)
    coeffs = []
    idx = 0
    while len(coeffs) < 256:
        b0, b1, b2 = data[idx], data[idx + 1], data[idx + 2]
        idx += 3
        d1 = b0 + 256 * (b1 & 0x0F)
        d2 = (b1 >> 4) + 16 * b2
        if d1 < Q:
            coeffs.append(d1)
        if len(coeffs) < 256 and d2 < Q:
            coeffs.append(d2)
    return coeffs


if __name__ == "__main__":
    c = sample_ntt(bytes(32), 0, 0)
    print(c[:16])
