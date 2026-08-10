#Reference ML-KEM (Kyber) NTT, mod 3329, for cross-checking the hardware
import os

MOD = 3329
N = 256

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

print("================================")
print(f"NTT INPUT (mod {MOD})")
print("================================")
for i in range(N):
    print(f"in[{i}] = {seq[i]}")

print()
print("================================")
print(f"KYBER NTT OUTPUT (mod {MOD})")
print("================================")
for i in range(N):
    print(f"out[{i}] = {r[i]}")
