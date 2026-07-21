# Recovered-key formats

Each recovered key describes an ordered support

```
L = (L_0, ..., L_{n-1}) in GF(2^m)^n
```

and a monic irreducible Goppa polynomial

```
g(X) = g_0 + g_1 X + ... + g_r X^r.
```

The support order is significant: entry `L_i` corresponds to column `i` of the public parity-check matrix. Polynomial coefficients are always ordered from constant term to leading term.

## Canonical JSON

`secret_key_tii_<N>.json` is the canonical, self-describing form. Let

```
GF(2^m) = GF(2)[a] / (f(a)),
```

where `f` is `field_modulus`. An integer `v` in `support` or `polynomial_coefficients` is a polynomial-basis bit mask: if

```
v = v_0 + 2 v_1 + ... + 2^(m-1) v_(m-1),  v_i in {0,1},
```

then it represents

```
v_0 + v_1 a + ... + v_(m-1) a^(m-1) in GF(2^m).
```

Equivalently, Sage reconstructs it with `field.from_integer(v)`. This definition is independent of Sage and is the recommended interface for new Python, Magma, Julia, Rust, or C verifiers. The `public_key_sha256` member binds the candidate to the exact public-key file used during recovery.

## Original TII Track-2 text

`sk_McEliece_<N>.txt` is accepted by the official TII [`check_solution_track2.sage`](https://github.com/ElenaKirshanova/tii_decoding_challenge/blob/e502cd59f8b1b3f05bf251a4f66d2b17f5602a63/check_solution_track2.sage). It has exactly two lines:

1. a Sage list of `g_0, ..., g_r`, expressed as polynomials in the field generator `a`;
2. a Sage list of the ordered support `L_0, ..., L_(n-1)`, also expressed in `a`.

The field modulus comes from the matching public TII challenge file. The conventional upstream filename is `sk_McEliece_<N>.txt`.

## Hemmert Sage pickle

`secret_key_tii_<N>.pckl` is a protocol-4 Sage/Python pickle of the two-element list `[L, g]`, matching the layout consumed by Hemmert's [`verify_secret_key.sage`](https://github.com/tobhem/key-recovery-mceliece-tii-solutions/blob/25f53056fd4a7331d2914940d110aa48e69454d7/verify_secret_key.sage).

This format is provided only for compatibility. Pickle is language- and Sage-version-specific, is not self-describing, and may execute arbitrary code when loaded. Never load a pickle obtained from an untrusted source. Prefer canonical JSON for new verifiers.

## Regeneration

The compatibility files are deterministic views of the canonical JSON for a given Sage version:

```bash
sage export_secret_keys.sage all
sage export_secret_keys.sage 252 tii /tmp/tii-keys
```

The exporter validates field-element bounds, dimensions, support uniqueness, nonvanishing on the support, and monicity/irreducibility before writing either view.
