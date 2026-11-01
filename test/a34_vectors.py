#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Pin-level test vectors and expected results for the A34 SiliconForge chip.

The chip has no ready/valid pins, so a tester drives and samples the pins on
fixed clock cycles counted from reset release. This script

* computes the bit-exact expected result of the approximate FP16 multiplier
  with Q16.16 accumulation (same arithmetic as src/rtl), and
* writes a cycle-by-cycle vector file that a pattern generator, FPGA or the
  pin-level testbench test/pin_tb.sv can replay.

Python standard library only.

Examples:
  python3 test/a34_vectors.py --selftest
  python3 test/a34_vectors.py --identity -o identity.vec
  python3 test/a34_vectors.py --suite -o suite.vec
  python3 test/a34_vectors.py \
      --cases signoff/q16_eco_full4/gl_regression/results/cases.json \
      -o cases.vec
  python3 test/a34_vectors.py --random 100 --seed 1 -o random.vec
"""
import argparse
import json
import random
import re
import struct
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Pin timing, counted in rising clock edges after reset release.
# Edge 0 is the first rising edge with rst_n = 1. Inputs change on the falling
# edge before a rising edge; outputs are sampled on the falling edge after it.
# Taken from simulation and checked by test/run_pin_test.sh (TEST_PLAN.md).
# ---------------------------------------------------------------------------
RESET_EDGES = 4                    # rising edges with rst_n = 0 before edge 0
PACKET_START = (0, 18, 36, 54)     # first input byte of packets 0..3
BYTES_PER_PACKET = 16
OUTPUT_START = 126                 # nibble j is on the pins after rising
#                                    edges 126+2j and 127+2j (two samples)
OUTPUT_NIBBLES = 128
LAST_EDGE = OUTPUT_START + 2 * OUTPUT_NIBBLES + 3   # a few zero samples after


def input_edges():
    return [s + k for s in PACKET_START for k in range(BYTES_PER_PACKET)]


def output_edges():
    """Recommended sample point of each nibble (second of its two samples)."""
    return [OUTPUT_START + 1 + 2 * j for j in range(OUTPUT_NIBBLES)]


def expected_pin(edge, nibbles):
    """Output pins sampled after rising edge `edge` (0 outside the window)."""
    k = edge - OUTPUT_START
    return nibbles[k // 2] if 0 <= k < 2 * OUTPUT_NIBBLES else 0


# ---------------------------------------------------------------------------
# Arithmetic model (bit-exact with src/rtl)
# ---------------------------------------------------------------------------
def fp16_bits(x):
    bits = struct.unpack('<H', struct.pack('<e', x))[0]
    if struct.unpack('<e', struct.pack('<H', bits))[0] != x:
        raise ValueError(f'{x} is not exactly representable in FP16')
    return bits


def approximate_product(a, b):
    """FP16 x FP16 -> FP16, as in fp16_approximate_multiplier.v."""
    sa, sb = (a >> 15) & 1, (b >> 15) & 1
    ea, eb = (a >> 10) & 31, (b >> 10) & 31
    ma, mb = a & 1023, b & 1023
    la = ma if ma < 512 else (1536 | (ma >> 1))
    lb = mb if mb < 512 else (1536 | (mb >> 1))
    lab = (la + lb) & 2047
    msb = (lab >> 10) & 1
    mp = lab & 1023 if msb == 0 else ((lab & 511) << 1)
    carry = int(bool((ma >> 9) & (mb >> 9))
                or (bool((ma >> 9) | (mb >> 9)) and not msb))
    exponent_sum = ea + eb
    if exponent_sum < 16:
        ep = 0
    else:
        normalized = exponent_sum - 15
        ep = 31 if normalized & 32 else (normalized + carry) & 31
    if (ea == 0 and ma == 0) or (eb == 0 and mb == 0) or ea == 31 or eb == 31:
        ep, mp = 0, 0
    return ((sa ^ sb) << 15) | (ep << 10) | mp


def fp16_to_q16_16(bits):
    """Signed Q16.16 integer, as in fp16_to_q16_16.v (saturating)."""
    sign, exp, frac = (bits >> 15) & 1, (bits >> 10) & 31, bits & 1023
    if exp == 0 and frac == 0:
        return 0
    if exp == 31:
        return 0 if frac else (-(1 << 31) if sign else (1 << 31) - 1)
    if exp == 0:
        magnitude = frac >> 8
        return -magnitude if sign else magnitude
    shift = (exp - 15) + 6
    mantissa = 1024 | frac
    if shift >= 0:
        magnitude = mantissa << shift
    else:
        magnitude = mantissa >> -shift
    magnitude &= (1 << 48) - 1
    if not sign:
        return min(magnitude, 0x7FFFFFFF)
    return -min(magnitude, 0x80000000)


def expected_words(a, b):
    """16 result words (row-major C[i][j]), each a 32-bit Q16.16 pattern."""
    words = []
    for i in range(4):
        for j in range(4):
            total = 0
            for k in range(4):
                p = approximate_product(fp16_bits(a[i][k]), fp16_bits(b[k][j]))
                total = (total + fp16_to_q16_16(p)) & 0xFFFFFFFF
            words.append(total)
    return words


# ---------------------------------------------------------------------------
# Pin encoding
# ---------------------------------------------------------------------------
def input_bytes(a, b):
    """64 bytes: packet p = row p of A then column p of B, MSB byte first."""
    out = []
    for p in range(4):
        words = [fp16_bits(a[p][k]) for k in range(4)]
        words += [fp16_bits(b[k][p]) for k in range(4)]
        packet = 0
        for w in words:
            packet = (packet << 16) | w
        out += [(packet >> (8 * (15 - n))) & 0xFF for n in range(16)]
    return out


def output_nibbles(words):
    """128 nibbles: element 0 first, most significant nibble first."""
    return [(w >> (4 * (7 - n))) & 0xF for w in words for n in range(8)]


def vector_lines(a, b, name=''):
    """One line per rising edge: rst_n in_byte check expected_pins (hex).

    Every sample is checked except the first reset edge (state before the
    first clock edge is undefined): zeros during reset and before the result,
    each nibble on two consecutive samples, then zeros again.
    """
    data = dict(zip(input_edges(), input_bytes(a, b)))
    nibbles = output_nibbles(expected_words(a, b))
    lines = [f'# matrix {name}'.rstrip()]
    lines += ['0 00 0 0'] + ['0 00 1 0'] * (RESET_EDGES - 1)
    for edge in range(LAST_EDGE + 1):
        byte, nib = data.get(edge, 0), expected_pin(edge, nibbles)
        lines.append(f'1 {byte:02x} 1 {nib:x}')
    return lines


def to_value(words, i):
    w = words[i]
    return (w - (1 << 32) if w & (1 << 31) else w) / 65536


# ---------------------------------------------------------------------------
# Command line
# ---------------------------------------------------------------------------
def selftest(results_dir):
    cases = json.loads((results_dir / 'cases.json').read_text())
    rtl = {}
    for line in (results_dir / 'rtl.log').read_text().splitlines():
        m = re.fullmatch(r'CASE (\d+) ELEM (\d+) ([0-9a-f]{8})', line.strip())
        if m:
            row = rtl.setdefault(int(m[1]), {})
            if int(m[2]) in row:
                raise ValueError('Duplicate recorded result')
            row[int(m[2])] = int(m[3], 16)
    if len(cases) != 33 or set(rtl) != set(range(33)):
        raise ValueError('Expected exactly the recorded 33 cases')
    if any(set(row) != set(range(16)) for row in rtl.values()):
        raise ValueError('Expected 16 known result words per case')
    bad = sum(expected_words(c['A'], c['B'])[e] != rtl[i][e]
              for i, c in enumerate(cases) for e in range(16))
    print(f'Model vs recorded RTL simulation: {33 * 16 - bad} of {33 * 16} '
          'result words match.')
    return bad == 0


def basic_suite():
    """Named silicon bring-up matrices (one matrix per reset)."""
    eye = [[1.0 if i == j else 0.0 for j in range(4)] for i in range(4)]
    zero = [[0.0] * 4 for _ in range(4)]
    seq = [[4 * i + j + 1.0 for j in range(4)] for i in range(4)]
    ones = [[1.0] * 4 for _ in range(4)]
    signed = [[(-1.0) ** (i + j) * (i + 1) for j in range(4)]
              for i in range(4)]
    big = [[64.0] * 4 for _ in range(4)]
    x4 = [[4.0 if i == j else 0.0 for j in range(4)] for i in range(4)]
    near = [[127.0 if i == j else 0.0 for j in range(4)] for i in range(4)]
    b256 = [[256.0 if i == j else 0.0 for j in range(4)] for i in range(4)]
    return [
        ('zero', zero, zero),                 # all results 0
        ('identity', seq, eye),               # C = A
        ('identity_left', eye, seq),          # C = B
        ('all_ones', ones, ones),             # every result 4.0
        ('signed', signed, seq),              # negative results
        ('negative_identity',
         seq, [[-x for x in r] for r in eye]),  # C = -A
        ('large_values', big, x4),  # 256.0, above the old Q8.8 maximum
        ('near_q16_limit', near, b256),  # 32512, just below +32768
        ('q16_wraparound', big, [[128.0] * 4 for _ in range(4)]),
        # 4 x 8192 = 32768 wraps to -32768 (documented Q16.16 behavior)
    ]


def random_matrix(rng):
    values = [x / 4 for x in range(-24, 25)]   # -6.0 .. 6.0 in steps of 0.25
    return [[rng.choice(values) for _ in range(4)] for _ in range(4)]


def main():
    here = Path(__file__).resolve().parent
    default_results = (here.parent / 'signoff/q16_eco_full4/gl_regression'
                       / 'results')
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    group = ap.add_mutually_exclusive_group(required=True)
    group.add_argument('--identity', action='store_true',
                       help='A = 1..16, B = identity')
    group.add_argument('--suite', action='store_true',
                       help='zero, identity, signed, large-value and '
                            'wrap-around bring-up matrices')
    group.add_argument('--cases', type=Path,
                       help='cases.json with A and B per case')
    group.add_argument('--random', type=int, metavar='N',
                       help='N random matrices with values in [-6, 6]')
    group.add_argument('--selftest', action='store_true',
                       help='check the model against the recorded RTL run')
    ap.add_argument('--seed', type=int, default=1)
    ap.add_argument('-o', '--output', type=Path,
                    help='vector file (default: standard output)')
    args = ap.parse_args()

    if args.selftest:
        return 0 if selftest(default_results) else 1
    if args.identity:
        a = [[4 * i + j + 1.0 for j in range(4)] for i in range(4)]
        b = [[1.0 if i == j else 0.0 for j in range(4)] for i in range(4)]
        mats = [('identity', a, b)]
    elif args.suite:
        mats = basic_suite()
    elif args.cases:
        mats = [(c.get('name', str(n)), c['A'], c['B'])
                for n, c in enumerate(json.loads(args.cases.read_text()))]
    else:
        rng = random.Random(args.seed)
        mats = [(f'random_{n}', random_matrix(rng), random_matrix(rng))
                for n in range(args.random)]
    lines = []
    for name, a, b in mats:
        lines += vector_lines(a, b, name)
    text = '\n'.join(lines) + '\n'
    if args.output:
        args.output.write_text(text)
        print(f'Wrote {len(mats)} matrix test(s) to {args.output}',
              file=sys.stderr)
    else:
        sys.stdout.write(text)
    return 0


if __name__ == '__main__':
    sys.exit(main())
