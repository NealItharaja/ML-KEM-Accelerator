#!/usr/bin/env python3
"""
ML-KEM reference

Usage:
  python mlkem_ref.py --selftest
  python mlkem_ref.py --level 512 --d <64hex> --z <64hex> --m <64hex>
"""

from __future__ import annotations

import argparse
import hashlib
import os
import sys

MOD = 3329
N = 256
R2 = 1353
N_PRIME = 3327
F_SCALE = 512

PARAMS = {
    512: dict(k=2, eta1=3, eta2=2, du=10, dv=4),
    768: dict(k=3, eta1=2, eta2=2, du=10, dv=4),
    1024: dict(k=4, eta1=2, eta2=2, du=11, dv=5),
}


def mont(T: int) -> int:
    m = (T * N_PRIME) & 0xFFFF
    t = (T + m * MOD) >> 16
    return t - MOD if t >= MOD else t


def fqmul(a: int, b: int) -> int:
    return mont(a * b)


def to_mont(a: int) -> int:
    return mont(a * R2)


def from_mont(a: int) -> int:
    return mont(a)


def _load_zetas():
    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(here, "..", "..", "src", "memory", "twiddle.mem")

    with open(path) as f:
        return [int(x, 16) for x in f.read().split()]


ZETAS = _load_zetas()


def ntt(a: list[int]) -> list[int]:
    # Coeffs must already be Montgomery-domain
    r = a[:]
    k = 1
    length = 128

    while length >= 2:
        start = 0
        while start < N:
            zeta = ZETAS[k]
            k += 1
            for j in range(start, start + length):
                t = fqmul(zeta, r[j + length])
                r[j + length] = (r[j] - t) % MOD
                r[j] = (r[j] + t) % MOD
            start += 2 * length
        length >>= 1
    return r


def intt(a: list[int]) -> list[int]:
    r = a[:]
    k = 127
    length = 2

    while length <= 128:
        start = 0
        while start < N:
            zeta = ZETAS[k]
            k -= 1
            for j in range(start, start + length):
                t = r[j]
                r[j] = (t + r[j + length]) % MOD
                r[j + length] = fqmul(zeta, (r[j + length] - t) % MOD)
            start += 2 * length
        length <<= 1
    for i in range(N):
        r[i] = fqmul(r[i], F_SCALE)
    return r


def sample_ntt(rho: bytes, x: int, y: int) -> list[int]:
    data = hashlib.shake_128(rho + bytes([x, y])).digest(8000)
    coeffs = []
    idx = 0

    while len(coeffs) < N:
        b0, b1, b2 = data[idx], data[idx + 1], data[idx + 2]
        idx += 3
        d1 = b0 + 256 * (b1 & 0x0F)
        d2 = (b1 >> 4) + 16 * b2

        if d1 < MOD:
            coeffs.append(d1)
        if len(coeffs) < N and d2 < MOD:
            coeffs.append(d2)
    return coeffs


def sample_cbd(eta: int, seed: bytes, nonce: int) -> list[int]:
    B = hashlib.shake_256(seed + bytes([nonce])).digest(64 * eta)
    bits = []

    for byte in B:
        for t in range(8):
            bits.append((byte >> t) & 1)
    out = []

    for i in range(N):
        x = sum(bits[2 * i * eta + j] for j in range(eta))
        y = sum(bits[2 * i * eta + eta + j] for j in range(eta))
        out.append((x - y) % MOD)
    return out


def basemul_poly(a: list[int], b: list[int]) -> list[int]:
    r = [0] * N

    for i in range(N // 4):
        zeta = ZETAS[64 + i]
        a0, a1 = a[4 * i], a[4 * i + 1]
        b0, b1 = b[4 * i], b[4 * i + 1]
        r[4 * i] = (fqmul(a0, b0) + fqmul(fqmul(a1, b1), zeta)) % MOD
        r[4 * i + 1] = (fqmul(a0, b1) + fqmul(a1, b0)) % MOD
        a0, a1 = a[4 * i + 2], a[4 * i + 3]
        b0, b1 = b[4 * i + 2], b[4 * i + 3]
        mz = (MOD - zeta) % MOD
        r[4 * i + 2] = (fqmul(a0, b0) + fqmul(fqmul(a1, b1), mz)) % MOD
        r[4 * i + 3] = (fqmul(a0, b1) + fqmul(a1, b0)) % MOD
    return r


def poly_add(a, b):
    return [(x + y) % MOD for x, y in zip(a, b)]


def poly_sub(a, b):
    return [(x - y) % MOD for x, y in zip(a, b)]


def compress(x: int, d: int) -> int:
    return (((x << d) + MOD // 2) // MOD) & ((1 << d) - 1)


def decompress(y: int, d: int) -> int:
    return (y * MOD + (1 << (d - 1))) >> d


def byte_encode(poly: list[int], d: int) -> bytes:
    buf = 0
    nbits = 0
    out = bytearray()

    for c in poly:
        v = c & ((1 << d) - 1)
        buf |= v << nbits
        nbits += d

        while nbits >= 8:
            out.append(buf & 0xFF)
            buf >>= 8
            nbits -= 8
    if nbits:
        out.append(buf & 0xFF)
    return bytes(out)


def byte_decode(data: bytes, d: int) -> list[int]:
    coeffs = []
    buf = 0
    nbits = 0
    idx = 0

    while len(coeffs) < N:
        while nbits < d:
            buf |= data[idx] << nbits
            nbits += 8
            idx += 1
        coeffs.append(buf & ((1 << d) - 1))
        buf >>= d
        nbits -= d
    return coeffs


def G(data: bytes) -> bytes:
    return hashlib.sha3_512(data).digest()


def H(data: bytes) -> bytes:
    return hashlib.sha3_256(data).digest()


def J(data: bytes, outlen: int = 32) -> bytes:
    return hashlib.shake_256(data).digest(outlen)


def poly_to_mont(p):
    return [to_mont(x) for x in p]


def poly_from_mont(p):
    return [from_mont(x) for x in p]


def ntt_normal(p):
    return ntt(poly_to_mont(p))


def intt_normal(p):
    return poly_from_mont(intt(p))


def matvec_ntt(A, s, k):
    t = [[0] * N for _ in range(k)]

    for i in range(k):
        acc = [0] * N
        for j in range(k):
            acc = poly_add(acc, basemul_poly(A[i][j], s[j]))
        t[i] = acc
    return t


def k_pke_keygen(d: bytes, level: int):
    p = PARAMS[level]
    k, eta1 = p["k"], p["eta1"]
    g = G(d + bytes([k]))
    rho, sigma = g[:32], g[32:]
    s = [ntt_normal(sample_cbd(eta1, sigma, i)) for i in range(k)]
    e = [ntt_normal(sample_cbd(eta1, sigma, i + k)) for i in range(k)]
    A = [[None] * k for _ in range(k)]

    for i in range(k):
        for j in range(k):
            A[i][j] = poly_to_mont(sample_ntt(rho, j, i))
    t = matvec_ntt(A, s, k)
    t = [poly_add(t[i], e[i]) for i in range(k)]
    t_enc = [poly_from_mont(t[i]) for i in range(k)]
    s_enc = [poly_from_mont(s[i]) for i in range(k)]
    pk = b"".join(byte_encode(t_enc[i], 12) for i in range(k)) + rho
    sk_pke = b"".join(byte_encode(s_enc[i], 12) for i in range(k))
    return pk, sk_pke, rho, s, t


def k_pke_encrypt(pk: bytes, m: bytes, r_coins: bytes, level: int):
    p = PARAMS[level]
    k, eta1, eta2, du, dv = p["k"], p["eta1"], p["eta2"], p["du"], p["dv"]
    t_bytes = pk[: 384 * k]
    rho = pk[384 * k :]
    t = [poly_to_mont(byte_decode(t_bytes[384 * i : 384 * (i + 1)], 12)) for i in range(k)]
    A = [[poly_to_mont(sample_ntt(rho, j, i)) for j in range(k)] for i in range(k)]
    r = [ntt_normal(sample_cbd(eta1, r_coins, i)) for i in range(k)]
    e1 = [sample_cbd(eta2, r_coins, i + k) for i in range(k)]
    e2 = sample_cbd(eta2, r_coins, 2 * k)
    At = [[A[j][i] for j in range(k)] for i in range(k)]
    u_hat = matvec_ntt(At, r, k)
    u = [poly_add(intt_normal(u_hat[i]), e1[i]) for i in range(k)]
    v_acc = [0] * N

    for i in range(k):
        v_acc = poly_add(v_acc, basemul_poly(t[i], r[i]))

    v = poly_add(intt_normal(v_acc), e2)
    mu = byte_decode(m, 1)
    mu = [decompress(x, 1) for x in mu]
    v = poly_add(v, mu)
    c1 = b"".join(byte_encode([compress(c, du) for c in u[i]], du) for i in range(k))
    c2 = byte_encode([compress(c, dv) for c in v], dv)
    return c1 + c2


def k_pke_decrypt(sk_pke: bytes, ct: bytes, level: int):
    p = PARAMS[level]
    k, du, dv = p["k"], p["du"], p["dv"]
    s = [poly_to_mont(byte_decode(sk_pke[384 * i : 384 * (i + 1)], 12)) for i in range(k)]
    c1_len = 32 * du * k
    c1, c2 = ct[:c1_len], ct[c1_len:]
    u = []
    step = 32 * du

    for i in range(k):
        comp = byte_decode(c1[step * i : step * (i + 1)], du)
        u.append([decompress(c, du) for c in comp])

    v_comp = byte_decode(c2, dv)
    v = [decompress(c, dv) for c in v_comp]
    u_hat = [ntt_normal(u[i]) for i in range(k)]
    acc = [0] * N

    for i in range(k):
        acc = poly_add(acc, basemul_poly(s[i], u_hat[i]))

    w = poly_sub(v, intt_normal(acc))
    return byte_encode([compress(c, 1) for c in w], 1)


def keygen(d: bytes, z: bytes, level: int):
    pk, sk_pke, _, _, _ = k_pke_keygen(d, level)
    h = H(pk)
    sk = sk_pke + pk + h + z
    return pk, sk


def encaps(pk: bytes, m: bytes, level: int):
    K_bar_r = G(m + H(pk))
    K_bar, r = K_bar_r[:32], K_bar_r[32:]
    ct = k_pke_encrypt(pk, m, r, level)
    return ct, K_bar


def decaps(sk: bytes, ct: bytes, level: int):
    p = PARAMS[level]
    k = p["k"]
    sk_pke_len = 384 * k
    pk = sk[sk_pke_len : sk_pke_len + 384 * k + 32]
    h = sk[sk_pke_len + 384 * k + 32 : sk_pke_len + 384 * k + 64]
    z = sk[sk_pke_len + 384 * k + 64 :]
    sk_pke = sk[:sk_pke_len]
    m_prime = k_pke_decrypt(sk_pke, ct, level)
    Kr = G(m_prime + h)
    K_bar, r_prime = Kr[:32], Kr[32:]
    ct_prime = k_pke_encrypt(pk, m_prime, r_prime, level)

    if ct_prime == ct:
        return K_bar
    return J(z + ct)


def selftest() -> bool:
    ok = True
    seq = [(i * 7 + 13) % MOD for i in range(N)]
    rt = intt_normal(ntt_normal(seq))
    if rt != seq:
        print("FAIL NTT/INTT roundtrip")
        ok = False
    else:
        print("PASS NTT/INTT roundtrip")

    for level in (512, 768, 1024):
        d = bytes([i for i in range(32)])
        z = bytes([255 - i for i in range(32)])
        m = bytes([(i * 3) & 0xFF for i in range(32)])
        pk, sk = keygen(d, z, level)
        ct, ss = encaps(pk, m, level)
        ss2 = decaps(sk, ct, level)
        if ss == ss2:
            print(f"PASS ML-KEM-{level} roundtrip ss={ss.hex()[:16]}...")
        else:
            print(f"FAIL ML-KEM-{level}")
            print(" ss ", ss.hex())
            print(" ss2", ss2.hex())
            ok = False
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--level", type=int, default=512, choices=[512, 768, 1024])
    ap.add_argument("--d", type=str, help="32-byte keygen seed hex")
    ap.add_argument("--z", type=str, help="32-byte implicit reject seed hex")
    ap.add_argument("--m", type=str, help="32-byte message hex")
    args = ap.parse_args()

    if args.selftest:
        sys.exit(0 if selftest() else 1)

    if not (args.d and args.z and args.m):
        ap.error("need --d --z --m or --selftest")

    d = bytes.fromhex(args.d)
    z = bytes.fromhex(args.z)
    m = bytes.fromhex(args.m)
    pk, sk = keygen(d, z, args.level)
    ct, ss = encaps(pk, m, args.level)
    ss2 = decaps(sk, ct, args.level)
    print(f"PK_HEX={pk.hex()}")
    print(f"SK_HEX={sk.hex()}")
    print(f"CT_HEX={ct.hex()}")
    print(f"SS_HEX={ss.hex()}")
    print(f"SS2_HEX={ss2.hex()}")
    sys.exit(0 if ss == ss2 else 1)


if __name__ == "__main__":
    main()
