"""Write cases.hex (4 packets per case) and cases.json (A, B, kind)."""
import json, random, struct
import numpy as np

def f16(x):
    return struct.unpack('<H', struct.pack('<e', x))[0]

def f16val(x):
    return float(np.float16(x))

cases = []
I = np.eye(4)
cases.append(("exact", "identity", I, I))
cases.append(("exact", "all-ones", np.ones((4, 4)), np.ones((4, 4))))
P = np.eye(4)[[2, 0, 3, 1]]
cases.append(("exact", "permutation", P, np.arange(16).reshape(4, 4) - 8.0))
random.seed(2027)
P2 = [0, 0, 1, -1, 2, -2, 0.5, -0.5, 4, -4, 0.25, -0.25, 8, -8, 16, -16, 32, -32]
for t in range(20):
    A = np.array([[random.choice(P2) for _ in range(4)] for _ in range(4)])
    B = np.array([[random.choice(P2) for _ in range(4)] for _ in range(4)])
    cases.append(("exact", f"pow2-{t}", A, B))
rng = np.random.default_rng(7)
for t in range(10):
    A = np.vectorize(f16val)(rng.uniform(-6, 6, (4, 4)))
    B = np.vectorize(f16val)(rng.uniform(-6, 6, (4, 4)))
    cases.append(("approx", f"general-{t}", A, B))

lines = []
for _, _, A, B in cases:
    for p in range(4):
        words = [f16(A[p][k]) for k in range(4)] + [f16(B[k][p]) for k in range(4)]
        lines.append("".join(f"{w:04x}" for w in words))
open("cases.hex", "w").write("\n".join(lines) + "\n")
json.dump([{"kind": k, "name": n, "A": A.tolist(), "B": B.tolist()} for k, n, A, B in cases],
          open("cases.json", "w"))
print(len(cases), "cases")
