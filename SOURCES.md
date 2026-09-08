# Sources and provenance of the original challenge data

Every recovered key in this repository is bound to a specific public
parity-check matrix by SHA-256. The public keys under `tii_public_keys/` are
verbatim copies of the upstream challenge files, digest-matched at the time
they were vendored. This file records where each one comes from so the copies
can be re-fetched and re-checked independently.

## Original TII decoding challenge (public keys)

The six newly-solved challenges take their public keys from the official TII
McEliece key-recovery challenge repository:

- **Upstream:** <https://github.com/ElenaKirshanova/tii_decoding_challenge>
- **Path:** `public_keyRec/pk_McEliece_<N>.txt`
- **Pinned commit:** `e502cd59f8b1b3f05bf251a4f66d2b17f5602a63` (2024-03-26)

These files use the original NumPy layout: one bracketed binary row per line,
followed by a trailing comma-separated row holding the coefficients of the
`GF(2^m)` defining polynomial (that trailing row is metadata, not part of the
parity-check matrix). `verify_recovered_key.sage` parses this format directly.

| Challenge | vendored as | upstream file |
|-----------|-------------|---------------|
| TII-129 | `tii_public_keys/tii_129.txt` | `public_keyRec/pk_McEliece_129.txt` |
| TII-213 | `tii_public_keys/tii_213.txt` | `public_keyRec/pk_McEliece_213.txt` |
| TII-240 | `tii_public_keys/tii_240.txt` | `public_keyRec/pk_McEliece_240.txt` |
| TII-246 | `tii_public_keys/tii_246.txt` | `public_keyRec/pk_McEliece_246.txt` |
| TII-252 | `tii_public_keys/tii_252.txt` | `public_keyRec/pk_McEliece_252.txt` |
| TII-254 | `tii_public_keys/tii_254.txt` | `public_keyRec/pk_McEliece_254.txt` |

## Reproduction controls (Hemmert archive)

TII-83 and TII-248 are **not new**: their keys were already published by
T. Hemmert. We include them as reproduction controls — the same attack code
reproduces the already-known result. Their public keys are taken from the
Hemmert archive (a Python-literal list-of-lists), which is also digest-matched:

- **Upstream:** <https://github.com/tobhem/key-recovery-mceliece-tii-solutions>
- **Path:** `tii_public_keys/tii_<N>.txt`

| Challenge | vendored as | upstream file |
|-----------|-------------|---------------|
| TII-83  | `tii_public_keys/tii_83.txt`  | `tii_public_keys/tii_83.txt`  |
| TII-248 | `tii_public_keys/tii_248.txt` | `tii_public_keys/tii_248.txt` |

## SHA-256 of the vendored public keys

Each digest below equals the `public_key_sha256` recorded in the matching
`tii_secret_keys/secret_key_tii_<N>.json`. `verify_recovered_key.sage`
re-computes and re-checks this binding on every run.

```
8f1b37c515ca1a9301857032ad5dd112b33780f54fee8e0e857baa019940f2f4  tii_129.txt
4edef7f04ef7189941ba82457553a31bf100bd2d4ac50e04bb059fdd8f75e49e  tii_213.txt
efd88fa04d1c60052a3a0f0255e9e82ed5c215b09791e669384dff3db6f16a21  tii_240.txt
9b2fbe2c1ef54884d6628d7228b4695371eb7676ced2273f500b4c5b94690ec9  tii_246.txt
446059db69ea126339475b53d5c65969f6c0cde98f734cca87e167d84bafe067  tii_252.txt
d1b7c7d808d2f129ecbbf6ea3c1d69a0a37c6e811ff8a1d856da131d46d2ccd6  tii_254.txt
7980e22e84bf92ab5900c40e12dd6a019f55949f01c4d5209999f91f304271e4  tii_83.txt
1d5d4b1f8511d97203aa1f3ccd41e90c5fd405b452c713ae4e08479e5c164fc0  tii_248.txt
```

## Re-fetching the public keys

If you want to re-obtain the originals rather than trust the vendored copies:

```bash
git clone https://github.com/ElenaKirshanova/tii_decoding_challenge
cd tii_decoding_challenge && git checkout e502cd59f8b1b3f05bf251a4f66d2b17f5602a63
sha256sum public_keyRec/pk_McEliece_252.txt   # -> 446059db...e167d84bafe067
```

Compare the digest against the table above (and against the
`public_key_sha256` field in the corresponding recovered-key JSON).
