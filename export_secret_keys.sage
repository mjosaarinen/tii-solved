#!/usr/bin/env sage
"""Export canonical recovered-key JSON in verifier-compatible formats.

Usage:
    sage export_secret_keys.sage <TII_NUMBER|all>
    sage export_secret_keys.sage <TII_NUMBER|all> <all|tii|pickle>
    sage export_secret_keys.sage <TII_NUMBER|all> <all|tii|pickle> <DIRECTORY>

The default output directory is ``tii_secret_keys/`` and the default format is
``all``.  Two compatibility views are supported:

``tii``
    ``sk_McEliece_<N>.txt``, the original TII Track-2 two-line text format.
``pickle``
    ``secret_key_tii_<N>.pckl``, the ``[support, g]`` Sage pickle consumed by
    Hemmert's verifier.  Pickle files must never be loaded from an untrusted
    source.

The JSON files remain canonical.  Re-running this script replaces only the
selected generated views.
"""

import json
import os
import pickle
import re
import sys
import tempfile


def _script_dir():
    argv0 = sys.argv[0] if sys.argv else ""
    if argv0 and os.path.basename(argv0).startswith("export_secret_keys"):
        return os.path.dirname(os.path.abspath(argv0))
    return os.getcwd()


HERE = _script_dir()
SECRET_DIR = os.path.join(HERE, "tii_secret_keys")


def available_numbers():
    numbers = []
    for name in os.listdir(SECRET_DIR):
        match = re.fullmatch(r"secret_key_tii_(\d+)\.json", name)
        if match:
            numbers.append(match.group(1))
    return sorted(numbers, key=int)


def load_key(number):
    path = os.path.join(SECRET_DIR, "secret_key_tii_%s.json" % number)
    with open(path) as fh:
        doc = json.load(fh)

    params = doc.get("parameters") or doc.get("provenance")
    m = int(params["m"])
    r = int(params["r"])
    n = int(params["n"])
    modulus_string = (doc.get("field_modulus")
                      or doc["provenance"]["field_modulus"])
    support_integers = [int(v) for v in doc["support"]]
    polynomial_integers = [int(v)
                           for v in doc["polynomial_coefficients"]]

    limit = 1 << m
    if any(v < 0 or v >= limit
           for v in support_integers + polynomial_integers):
        raise ValueError("TII-%s: field element integer outside [0, 2^m)"
                         % number)
    if len(support_integers) != n:
        raise ValueError("TII-%s: support length does not match n" % number)
    if len(polynomial_integers) != r + 1:
        raise ValueError("TII-%s: coefficient count does not match r+1"
                         % number)

    binary_ring = PolynomialRing(GF(2), "x")
    modulus = binary_ring(modulus_string)
    if modulus.degree() != m or not modulus.is_irreducible():
        raise ValueError("TII-%s: invalid field modulus" % number)
    field = GF(2 ** m, "a", modulus=modulus)
    support = [field.from_integer(v) for v in support_integers]
    polynomial_ring = PolynomialRing(field, "X")
    g = polynomial_ring([field.from_integer(v)
                         for v in polynomial_integers])

    if len(set(support)) != n:
        raise ValueError("TII-%s: support contains duplicates" % number)
    if g.degree() != r or not g.is_monic() or not g.is_irreducible():
        raise ValueError("TII-%s: invalid Goppa polynomial" % number)
    if any(g(value) == 0 for value in support):
        raise ValueError("TII-%s: Goppa polynomial vanishes on support"
                         % number)
    return support, g


def atomic_write(path, data, binary):
    directory = os.path.dirname(os.path.abspath(path))
    os.makedirs(directory, exist_ok=True)
    fd, temporary_path = tempfile.mkstemp(prefix=".key-export-", dir=directory)
    try:
        if binary:
            with os.fdopen(fd, "wb") as fh:
                fh.write(data)
        else:
            with os.fdopen(fd, "w", encoding="ascii", newline="\n") as fh:
                fh.write(data)
        os.chmod(temporary_path, 0o644)
        os.replace(temporary_path, path)
    except BaseException:
        try:
            os.unlink(temporary_path)
        except FileNotFoundError:
            pass
        raise


def format_list(values):
    return "[" + ", ".join(str(value) for value in values) + "]"


def export_key(number, output_dir, output_format):
    support, g = load_key(number)
    written = []

    if output_format in ("all", "tii"):
        # This is exactly the layout consumed by check_solution_track2.sage:
        # low-to-high g coefficients on line 1, ordered support on line 2.
        text = format_list(list(g)) + "\n" + format_list(support) + "\n"
        path = os.path.join(output_dir, "sk_McEliece_%s.txt" % number)
        atomic_write(path, text, binary=False)
        written.append(path)

    if output_format in ("all", "pickle"):
        # Protocol 4 and the list shape match Hemmert's published key archive.
        data = pickle.dumps([support, g], protocol=4)
        path = os.path.join(output_dir, "secret_key_tii_%s.pckl" % number)
        atomic_write(path, data, binary=True)
        written.append(path)

    return written


def parse_arguments(argv):
    args = list(argv[1:])
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return None

    selector = args.pop(0)
    output_format = args.pop(0) if args else "all"
    if output_format not in ("all", "tii", "pickle"):
        raise ValueError("format must be all, tii, or pickle")
    output_dir = os.path.abspath(args.pop(0)) if args else SECRET_DIR
    if args:
        raise ValueError("too many arguments: %s" % " ".join(args))
    return selector, output_format, output_dir


def main(argv):
    parsed = parse_arguments(argv)
    if parsed is None:
        return 0
    selector, output_format, output_dir = parsed
    present = available_numbers()
    if selector == "all":
        numbers = present
    elif selector in present:
        numbers = [selector]
    else:
        raise ValueError("no canonical JSON key for TII-%s" % selector)

    for number in numbers:
        for path in export_key(number, output_dir, output_format):
            print("wrote %s" % os.path.relpath(path, HERE))
    print("Exported %d key(s) in %s format." % (len(numbers), output_format))
    return 0


_exit_status = main(sys.argv)
if _exit_status:
    raise RuntimeError("export failed with status %d" % _exit_status)
