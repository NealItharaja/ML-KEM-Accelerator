#Reference ML-KEM (Kyber) inverse NTT, mod 3329, for cross-checking the hardware.

#Run: python testbench/ntt/intt256_reference.py

import os

MOD = 3329
N = 256
F = 512  # R/128 for this montgomery.v (not Kyber-C's 1441)


def mont(T):
    m = (T * 3327) & 0xFFFF
    t = (T + m * MOD) >> 16
    return t - MOD if t >= MOD else t


def fqmul(a, b):
    return mont(a * b)


here = os.path.dirname(os.path.abspath(__file__))
tw_path = os.path.join(here, "..", "..", "src", "memory", "twiddle.mem")

with open(tw_path) as f:
    zetas = [int(x, 16) for x in f.read().split()]

seq = [(k * 7 + 13) % MOD for k in range(N)]
r = seq[:]
k = 1
length = 128

while length >= 2:
    start = 0
    while start < N:
        zeta = zetas[k]
        k += 1

        for j in range(start, start + length):
            t = fqmul(zeta, r[j + length])
            r[j + length] = (r[j] - t) % MOD
            r[j] = (r[j] + t) % MOD
        start = j + 1 + length
    length >>= 1

ntt_in = r[:]
r = ntt_in[:]
k = 127
length = 2

while length <= 128:
    start = 0

    while start < N:
        zeta = zetas[k]
        k -= 1
        for j in range(start, start + length):
            t = r[j]
            r[j] = (t + r[j + length]) % MOD
            r[j + length] = fqmul(zeta, (r[j + length] - t) % MOD)
        start = j + 1 + length
    length <<= 1

for j in range(N):
    r[j] = fqmul(r[j], F)

print("================================")
print(f"INTT INPUT = NTT(x) (mod {MOD})")
print("================================")
for i in range(N):
    print(f"in[{i}] = {ntt_in[i]}")

print()
print("================================")
print(f"KYBER INTT OUTPUT (mod {MOD})")
print("================================")
for i in range(N):
    print(f"out[{i}] = {r[i]}")

print()
if r == seq:
    print("ROUNDTRIP OK: INTT(NTT(x)) == x")
else:
    print("ROUNDTRIP FAIL")
    for i in range(N):
        if r[i] != seq[i]:
            print(f"  first mismatch at [{i}]: got {r[i]}, expected {seq[i]}")
            break
