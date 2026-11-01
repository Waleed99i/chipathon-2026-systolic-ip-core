"""Strict sampled RTL/GL comparison; failure always returns a nonzero exit code."""
import json
from pathlib import Path
import re
import sys
import numpy as np


def fail(message):
    raise ValueError(message)


def parse(path, count):
    text = Path(path).read_text()
    if re.search(r'TIMEOUT|FATAL:|ERROR:', text, re.I):
        fail(f'{path}: simulator reported an error or timeout')
    words, done = {}, set()
    for line in text.splitlines():
        if not line.startswith('CASE '):
            continue
        m = re.fullmatch(r'CASE (\d+) ELEM (\d+) ([0-9a-fA-FxXzZ]{8})', line.strip())
        if m:
            c, e, h = int(m[1]), int(m[2]), m[3].lower()
            if not (0 <= c < count and 0 <= e < 16):
                fail(f'{path}: unexpected case/element index {c}/{e}')
            if any(x in h for x in 'xz'):
                fail(f'{path}: unknown value at case {c}, element {e}: {h}')
            if e in words.setdefault(c, {}):
                fail(f'{path}: duplicate case {c}, element {e}')
            words[c][e] = int(h, 16)
            continue
        m = re.fullmatch(r'CASE (\d+) DONE at \d+', line.strip())
        if not m or not 0 <= int(m[1]) < count or int(m[1]) in done:
            fail(f'{path}: malformed, duplicate or unexpected record: {line}')
        done.add(int(m[1]))
    if set(words) != set(range(count)) or done != set(range(count)):
        fail(f'{path}: missing case data or completion record')
    for c in range(count):
        if set(words[c]) != set(range(16)):
            fail(f'{path}: case {c} does not contain exactly 16 result words')
    return words


def main():
    if len(sys.argv) != 3:
        fail('Usage: check.py rtl.log gl.log (run in the directory containing cases.json)')
    cases = json.loads(Path('cases.json').read_text())
    if len(cases) != 33 or sum(c['kind'] == 'exact' for c in cases) != 23:
        fail('Expected the reviewed 33-case suite: 23 exact, 10 general')
    rtl, gl = parse(sys.argv[1], len(cases)), parse(sys.argv[2], len(cases))
    errors, observations = [], []
    exact_pass, identical = 0, 0
    for i, case in enumerate(cases):
        a, b = np.array(case['A'], dtype=np.float64), np.array(case['B'], dtype=np.float64)
        if a.shape != (4, 4) or b.shape != (4, 4) or not np.all(np.isfinite([a, b])):
            fail(f'Invalid input matrices in case {i}')
        reference = a @ b
        if case['kind'] == 'exact':
            scaled = reference * 65536.0
            if not np.all(scaled == np.rint(scaled)) or not np.all((scaled >= -(2**31)) & (scaled < 2**31)):
                fail(f'Exact-case reference is not representable in Q16.16: {case["name"]}')
            expected = [int(x) & 0xffffffff for x in scaled.flat]
            good = all(rtl[i][e] == expected[e] for e in range(16))
            exact_pass += good
            if not good:
                errors.append(f'RTL exact arithmetic mismatch: {case["name"]}')
        elif case['kind'] == 'approx':
            got = np.array([((rtl[i][e] - 2**32) if rtl[i][e] >= 2**31 else rtl[i][e]) / 65536.0
                            for e in range(16)]).reshape(4, 4)
            # Matrix-normalized error, not maximum per-element relative error.
            denom = float(np.max(np.abs(reference)))
            if denom == 0:
                fail('General-case reference has zero normalization denominator')
            error = float(np.max(np.abs(got - reference)) / denom)
            observations.append({'case': case['name'], 'max_abs_error_over_max_abs_reference': error})
            print(f'{case["name"]:11s} max |RTL - exact| / max|exact| = {error:.6f}')
        else:
            fail(f'Unknown case kind: {case["kind"]}')
        equal = rtl[i] == gl[i]
        identical += equal
        if not equal:
            errors.append(f'GL/RTL word mismatch: {case["name"]}')
    print(f'RTL: {exact_pass}/23 exact-arithmetic cases match A@B bit-exactly in Q16.16')
    print(f'GL vs RTL: {identical}/33 cases bit-identical (16 known words per case)')
    Path('check_summary.json').write_text(json.dumps({
        'passed': not errors, 'cases': 33, 'exact_rtl_pass': exact_pass,
        'gl_rtl_pass': identical, 'observations': observations,
        'scope': 'Zero-delay, internal-handshake-assisted, one matrix per reset. Sampled comparison; no formal equivalence or universal accuracy bound.'
    }, indent=2) + '\n')
    if errors:
        fail('; '.join(errors))
    print('REGRESSION PASS')


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print(f'REGRESSION FAIL: {exc}', file=sys.stderr)
        sys.exit(1)
