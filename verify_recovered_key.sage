#!/usr/bin/env sage
"""Independently verify a recovered TII Goppa key against its public key.

Usage:
    sage verify_recovered_key.sage <TII_NUMBER>          # e.g. 252
    sage verify_recovered_key.sage all                   # verify every key present

This is a standalone script (no dependency on the attack code that produced the
keys).  For a public binary parity-check matrix ``H`` and a candidate support
``x`` and Goppa polynomial ``g`` over ``GF(2^m)``, it reconstructs the Goppa
parity check

    H_rec[j*r + k, l] = (y_l * x_l^k)^(2^j),   y_l = 1/g(x_l),
    0 <= k < r = deg g,   0 <= j < m,   0 <= l < n,

and accepts the key iff, over the extension field ``GF(2^m)``,

    RowSpace(H_rec) == RowSpace(H).

Comparing row spaces (rather than a particular echelon form) makes the check
insensitive to how ``H`` was stored.  The extension degree ``m``, Goppa degree
``r``, and code length ``n`` are checked against the published challenge
parameters, not re-derived from the candidate key.

Requires SageMath.  The recovered keys live in ``tii_secret_keys/`` and the
original public keys in ``tii_public_keys/`` (see README.md and SOURCES.md).
"""

import ast
import hashlib
import json
import os
import re
import sys

def _script_dir():
    # Sage execs a preparsed copy, so ``__file__`` points into the Sage package
    # rather than this script.  ``sys.argv[0]`` is the real path passed on the
    # command line; fall back to the current directory.
    argv0 = sys.argv[0] if sys.argv else ""
    if argv0 and os.path.basename(argv0).startswith("verify_recovered_key"):
        return os.path.dirname(os.path.abspath(argv0))
    return os.getcwd()


HERE = _script_dir()
SECRET_DIR = os.path.join(HERE, "tii_secret_keys")
PUBLIC_DIR = os.path.join(HERE, "tii_public_keys")

# Published Track-2 challenge parameters.  Keeping these outside the candidate
# JSON makes the m/r/n checks independent of the recovered key being tested.
CHALLENGE_PARAMETERS = {
    "83": (8, 5, 253),
    "129": (9, 9, 509),
    "213": (9, 10, 496),
    "240": (10, 11, 1010),
    "246": (10, 11, 1009),
    "248": (9, 7, 482),
    "252": (10, 11, 1008),
}


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def read_tii_public_key(path):
    """Return ``(binary rows, optional field-modulus coefficients)``.

    Accepts both published formats: Hemmert's Python-literal list-of-lists and
    the original TII/Kirshanova NumPy layout (one bracketed binary row per line
    with a trailing comma-separated field-modulus row that is *not* part of the
    parity-check matrix).
    """
    with open(path) as fh:
        text = fh.read()
    field_modulus_coefficients = None
    try:
        rows = ast.literal_eval(text)
    except SyntaxError:
        raw_rows = []
        for line in text.splitlines():
            if not line.strip():
                continue
            match = re.fullmatch(r"\s*\[([^\[\]]*)\]\s*", line)
            if match is None:
                raise ValueError("%s: invalid matrix row syntax" % path)
            raw_rows.append(match.group(1))
        rows = []
        for raw in raw_rows:
            if re.search(r"[^01,\s]", raw):
                raise ValueError("%s: invalid matrix syntax" % path)
            tokens = raw.replace(",", " ").split()
            if not tokens or any(tok not in ("0", "1") for tok in tokens):
                raise ValueError("%s: invalid binary row" % path)
            rows.append([int(tok) for tok in tokens])
        if len(rows) >= 2 and len(rows[-1]) != len(rows[0]):
            if any(len(r) != len(rows[0]) for r in rows[:-1]):
                raise ValueError("%s: ragged matrix rows" % path)
            # Separate the trailing defining-polynomial coefficient row.
            field_modulus_coefficients = rows.pop()
    if not rows or not all(isinstance(r, list) for r in rows):
        raise ValueError("%s: not a list of rows" % path)
    width = len(rows[0])
    for r in rows:
        if len(r) != width:
            raise ValueError("%s: ragged rows" % path)
        for v in r:
            if v not in (0, 1):
                raise ValueError("%s: non-binary entry %r" % (path, v))
    return rows, field_modulus_coefficients


def load_recovered_key(number):
    """Return ``(field, support, g, m, r, n, pk_sha256, pk_path)``."""
    key_path = os.path.join(SECRET_DIR, "secret_key_tii_%s.json" % number)
    with open(key_path) as fh:
        doc = json.load(fh)
    params = doc.get("parameters") or doc.get("provenance")
    m = int(params["m"])
    r = int(params["r"])
    n = int(params["n"])
    modulus_str = doc.get("field_modulus") or doc["provenance"]["field_modulus"]
    pk_sha256 = doc.get("public_key_sha256") or doc["provenance"]["public_key_sha256"]

    binary_ring = PolynomialRing(GF(2), "x")
    modulus = binary_ring(modulus_str)
    field = GF(2 ** m, "a", modulus=modulus)
    support = [field.from_integer(int(v)) for v in doc["support"]]
    poly_ring = PolynomialRing(field, "X")
    g = poly_ring([field.from_integer(int(v)) for v in doc["polynomial_coefficients"]])
    return field, support, g, m, r, n, pk_sha256, doc


def verify(number):
    field, x, g, m, r, n, expected_pk_sha, doc = load_recovered_key(number)
    pk_path = os.path.join(PUBLIC_DIR, "tii_%s.txt" % number)

    checks = {}
    reasons = []

    def check(name, cond, message):
        checks[name] = bool(cond)
        if not cond:
            reasons.append(message)

    # --- public key present and digest-bound ------------------------------- #
    have_pk = os.path.exists(pk_path)
    check("public_key_present", have_pk,
          "missing %s (see SOURCES.md to fetch it)" % pk_path)
    if not have_pk:
        return finish(number, checks, reasons)
    actual_pk_sha = sha256_file(pk_path)
    check("public_key_sha256_matches", actual_pk_sha == expected_pk_sha,
          "public key SHA-256 %s != recorded %s" % (actual_pk_sha, expected_pk_sha))

    public_rows, public_modulus = read_tii_public_key(pk_path)
    H = matrix(GF(2), public_rows)
    support_field = x[0].parent() if x else None
    field_degree = field.degree()
    deg_g = g.degree()

    expected_parameters = CHALLENGE_PARAMETERS.get(str(number))
    check("parameters_match_challenge",
          expected_parameters is not None and (m, r, n) == expected_parameters,
          "candidate parameters (m,r,n)=%r != published %r"
          % ((m, r, n), expected_parameters))

    # --- field / representation consistency -------------------------------- #
    check("public_matrix_over_gf2", H.base_ring().order() == 2,
          "H is not over GF(2)")
    check("field_matches_support", field == support_field,
          "working field != support elements' parent")
    check("g_base_ring_matches_support", g.base_ring() == support_field,
          "g.base_ring() does not match the support field")
    check("field_degree_matches_m", field_degree == m,
          "field degree %d != expected m=%d" % (field_degree, m))
    recovered_modulus = [int(c) for c in field.modulus()]
    check("field_modulus_matches_public",
          public_modulus is None or recovered_modulus == public_modulus,
          "candidate field modulus != modulus embedded in public key")
    check("goppa_degree_matches_r", deg_g == r,
          "deg(g)=%d != expected r=%d" % (deg_g, r))
    check("goppa_polynomial_monic", g.is_monic(),
          "g is not monic")
    check("goppa_polynomial_irreducible", g.is_irreducible(),
          "g is not irreducible")

    # --- support well-formedness ------------------------------------------- #
    check("length_matches", len(x) == n == H.ncols(),
          "len(x)=%d, candidate n=%d, public n=%d"
          % (len(x), n, H.ncols()))
    check("support_distinct", len(set(x)) == len(x),
          "support entries are not distinct")
    check("support_in_field", all(xi in field for xi in x),
          "some support entries are not in the field")
    check("g_nonvanishing", all(g(xi) != 0 for xi in x),
          "g vanishes at some support point")

    # --- proper-instance rank gate ----------------------------------------- #
    check("public_rank_is_mr", H.rank() == m * r,
          "rank(H)=%d != m*r=%d" % (H.rank(), m * r))

    # --- row-space reconstruction ------------------------------------------ #
    if all(checks.values()):
        y = [1 / g(xi) for xi in x]
        Hrec = matrix(field, field_degree * deg_g, len(x))
        for j in range(field_degree):
            tj = 1 << j
            for k in range(deg_g):
                row = j * deg_g + k
                for l in range(len(x)):
                    Hrec[row, l] = (y[l] * x[l] ** k) ** tj
        Hext = H.change_ring(field)
        check("rowspace_matches", Hrec.row_space() == Hext.row_space(),
              "reconstructed row space != public row space")
    else:
        checks["rowspace_matches"] = False
        reasons.append("skipped row-space check (a precondition failed)")

    return finish(number, checks, reasons)


def finish(number, checks, reasons):
    ok = bool(checks) and all(checks.values())
    print("== TII-%s ==" % number)
    width = max(len(k) for k in checks) if checks else 0
    for name, value in checks.items():
        print("  [%s] %s" % ("PASS" if value else "FAIL", name.ljust(width)))
    for reason in reasons:
        print("  - %s" % reason)
    print("  %d/%d checks passed" % (sum(1 for v in checks.values() if v), len(checks)))
    print("Secret key is CORRECT." if ok else "Secret key is INCORRECT.")
    print("")
    return ok


def available_numbers():
    numbers = []
    for name in sorted(os.listdir(SECRET_DIR)):
        m = re.fullmatch(r"secret_key_tii_(\d+)\.json", name)
        if m:
            numbers.append(m.group(1))
    return sorted(numbers, key=int)


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 2
    arg = argv[1]
    numbers = available_numbers() if arg == "all" else [arg]
    results = {n: verify(n) for n in numbers}
    if len(results) > 1:
        good = sum(1 for v in results.values() if v)
        print("Summary: %d/%d keys CORRECT (%s)"
              % (good, len(results),
                 ", ".join("TII-%s:%s" % (n, "ok" if v else "FAIL")
                           for n, v in results.items())))
    return 0 if all(results.values()) else 1


# Sage executes this file with ``__name__ == "sage.all"`` (not "__main__"), so
# invoke main() directly.  Raising only on failure avoids Sage treating even a
# successful ``sys.exit(0)`` as an interpreter error.
_exit_status = main(sys.argv)
if _exit_status:
    raise RuntimeError("verification failed with status %d" % _exit_status)
