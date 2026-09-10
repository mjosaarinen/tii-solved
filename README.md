# tii-solved — recovered keys for previously unsolved TII McEliece challenges

Markku-Juhani O. Saarinen `<markku-juhani.saarinen@tuni.fi>`

This repository is laid out in the same style as T. Hemmert's
[`key-recovery-mceliece-tii-solutions`](https://github.com/tobhem/key-recovery-mceliece-tii-solutions): public keys, recovered secret keys, and one script that checks a recovered key against its public key.

Of the new recoveries, up to TII-252 was obtained using ["HOVER: Higher-Order Vanishing Endomorphism Recovery"](https://eprint.iacr.org/2026/1778) in late July 2026. TII-254 was attacked with "Two-Anchor Holdout/Hermite" and required substantially more effort; see [`tii254-artifact`](https://github.com/mjosaarinen/tii254-artifact). This solution was obtained on September 8, 2026.

TII-253 was solved on [August 19, 2026 by Steve Weis (Anthropic AI)](https://github.com/sweis/mceliece-challenges/blob/main/sk_McEliece_253.txt); our TII-254 is the current record at the time of writing (as far as we know.) Of the original challenges, TII-255 remains to be conquered.

## Results

Originally (2023), the number labels in TII challenges referred to the "bit security" of the challenge, but this has been known to be inaccurate. 

All eight keys are recovered and independently verified: the recovered support
`x` and Goppa polynomial `g` reconstruct exactly the public parity-check row
space over `GF(2^m)` (see *Verifying* below). TII-254 is an equivalent binary
Goppa decoding key; it is not claimed to be the challenge author's original
support and polynomial representation.

| Challenge | m | r | n | status | method | wall time | memory | system |
|-----------|---|---|------|------|--------|-----------|--------|--------|
| **TII-254** | 8 | 12 | 223 | **new*** | 2-Anchor | 16h Wall | 128 GiB | GH200s |
| **TII-252** | 10 | 11 | 1008 | **new** | HOVER | 6 min 15 s | 2.7 GiB | 12-core laptop |
| **TII-246** | 10 | 11 | 1009 | **new** | HOVER | 3 min 11 s | 2.7 GiB | 12-core laptop |
| **TII-240** | 10 | 11 | 1010 | **new** | HOVER | 3 min 06 s | 2.7 GiB | 12-core laptop |
| **TII-213** | 9 | 10 | 496 | **new** | HOVER | 6 h 45 min | 144 GiB | 28-vCPU server |
| **TII-129** | 9 | 9 | 509 | **new** | HOVER | 4 h 30 min | 80 GiB | 28-vCPU server |
| TII-248 | 9 | 7 | 482 | control | HOV | 13 min 38 s | 0.4 GiB | 12-core laptop |
| TII-83  | 8 | 5 | 253 | control | HOV | 24 s | 1.7 GiB | 12-core laptop |

`m` = field extension degree, `r` = Goppa degree (= `deg g`), `n` = code
length (= `|support|`). *Wall time* and *memory* (peak resident set of the
largest process) are measured on the stated **system**: the **12-core laptop**
is an AMD Ryzen AI 9 HX 370 (12 cores / 24 threads, 30 GiB); the **28-vCPU
server** is a larger-memory machine used only for the two recoveries whose
working set exceeds 30 GiB (TII-129/213), whose keys are then re-verified on
the laptop. Core counts follow the paper's convention of physical cores, not
hardware threads. Per-run records are in `timings/`.



**Controls vs. Hemmert.** TII-83 and TII-248 reproduce keys already published by Hemmert, so they double as a head-to-head against ePrint 2026/1339, Table 1, whose figures were measured on a **2×128-core server** (two AMD EPYC 9745, 128 cores each):

| Control | Hemmert — 2×128-core server | this work — 12-core laptop | speedup |
|---------|-----------------------------|----------------------------|---------|
| TII-83  | 13 min, 1.7 GB      | 24 s, 1.7 GiB          | ~32× |
| TII-248 | 17 h 18 min, 0.5 GB | 13 min 38 s, 0.4 GiB   | ~76× |

Recovering the identical key, the implementation here is roughly **30×–75× faster than the paper's prototype on a machine with a fraction of the core**.

The three degree-three `(m,r)=(10,11)` recoveries (240/246/252) re-derive **byte-identical** support and Goppa polynomials in minutes; their largest single process stays ~2.7 GiB (a transient 16-process Goppa-reconstruction pool peaks near ~10 GiB total). The two `m=9` recoveries (129/213) are dominated by an expensive binary kernel computation needing 80–144 GiB of RAM, so they run on the larger-memory server (`timings/tii_129_recovery.txt`, `tii_213_recovery.txt`)
and are re-verified on the laptop.

## Layout

```
tii_public_keys/              # original public parity-check matrices
  tii_129.txt … tii_254.txt   # new challenges (from ElenaKirshanova/tii_decoding_challenge)
  tii_83.txt  tii_248.txt     # controls (from the Hemmert archive)
tii_secret_keys/              # canonical recovered keys + compatibility exports
  secret_key_tii_<N>.json     # canonical: field-basis integers + parameters + provenance
  sk_McEliece_<N>.txt         # original TII Track-2 two-line text format
  secret_key_tii_<N>.pckl     # Sage [support, g] format used by Hemmert's verifier
verify_recovered_key.sage     # standalone SageMath verifier (no external dependencies)
export_secret_keys.sage       # regenerate text/pickle views from the canonical JSON
KEY_FORMATS.md                # exact representation and interoperability specification
timings/                      # verification + end-to-end run records
  tii_<N>_laptop_run.txt      # end-to-end recovery re-run here
  tii_<N>_verify.txt          # independent verification here
  tii_129/213_recovery.txt    # large-memory-machine recovery records
SOURCES.md                    # upstream URLs, pinned commit, and SHA-256 of every public key
```

The readable JSON is the canonical form. Each `secret_key_tii_<N>.json`
carries the support and Goppa-polynomial coefficients as canonical `GF(2^m)`
integers, the field-defining polynomial, the parameters `(m,r,n)`, the SHA-256
of the public key it was recovered against, and attack provenance. This
includes `p,s` and seed values for the HOVER runs where applicable; TII-254
instead binds its pair-core method and sealed result/validation identities.
The `.txt` and `.pckl` files are generated compatibility views; see
[KEY_FORMATS.md](KEY_FORMATS.md) for the exact field-element mapping and
consumer details.

## Interoperable key formats

The checked-in `sk_McEliece_<N>.txt` files use the original TII Track-2 private-key layout and can be passed directly to the official `check_solution_track2.sage`. The checked-in `secret_key_tii_<N>.pckl` files use the `[support, g]` object layout consumed by Hemmert's verifier. Because Python pickle can execute code while loading, use a pickle only when it came from a trusted checkout; the JSON or TII text form is preferable for new tooling.

Both views can be regenerated from one key or all canonical keys:

```bash
sage export_secret_keys.sage 252
sage export_secret_keys.sage all
```

The optional second argument selects `tii` or `pickle` instead of both; an optional third argument sets the output directory. For example, `sage export_secret_keys.sage 252 tii /tmp/tii-keys` writes only the TII text view elsewhere.

## Verifying

The verifier needs only SageMath. From the repository root:

```bash
sage verify_recovered_key.sage 252     # verify one challenge
sage verify_recovered_key.sage all     # verify every key present
```

For each key it rebuilds `GF(2^m)` from the stored modulus, maps the support and polynomial back to field elements, re-computes the SHA-256 of the public key and checks it against the value the recovery was bound to, and then reconstructs the Goppa parity check

```
H_rec[j*r + k, l] = (y_l · x_l^k)^(2^j),   y_l = 1/g(x_l),
0 ≤ k < r = deg g,   0 ≤ j < m,   0 ≤ l < n
```

accepting the key iff `RowSpace(H_rec) == RowSpace(H)` over `GF(2^m)`. Comparing row spaces (not a particular echelon form) makes the check independent of how `H` was stored. The parameters `(m,r,n)` are checked against a verifier-owned table of published challenge parameters, and the field modulus is checked against the copy embedded in the original TII public key when present. The verifier also requires a monic irreducible Goppa polynomial. All 17 checks must pass for a key to be reported `CORRECT`.


## Original challenge data

The public keys are verbatim copies of the upstream challenge files, bound to
each recovered key by SHA-256. See **[SOURCES.md](SOURCES.md)** for the upstream
repositories, the pinned commit, the full digest table, and how to re-fetch
and re-check the originals. In short, the six new challenges come from the
official TII challenge repository
[`ElenaKirshanova/tii_decoding_challenge`](https://github.com/ElenaKirshanova/tii_decoding_challenge)
(`public_keyRec/pk_McEliece_<N>.txt`), and the two controls from the Hemmert
archive.
