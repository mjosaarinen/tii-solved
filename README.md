# tii-solved — recovered keys for previously unsolved TII McEliece challenges

July 21, 2026 -- Markku-Juhani O. Saarinen `<markku-juhani.saarinen@tuni.fi>`


At the end of June 2026, Tobias Hemmert (BSI) published IACR ePrint 2026/1339, ["Key recovery for the McEliece cryptosystem using higher-order vanishing"](https://eprint.iacr.org/2026/1339). In the work, Hemmert presents a new key recovery attack against the McEliece cryptosystem with binary Goppa codes that applies to a wide range of parameter sets. Hemmert also published solutions to TII McEliece key recovery challenges.

This repository publishes further recovered secret keys for [TII McEliece key-recovery challenges](https://crowdchallenge.tii.ae/mceliece-challenges/) that were broken with a new **HOVER** ("Higher-Order Vanishing Endomorphism Recovery") variant of Hemmert's HOV attack.

This repository is laid out in the same style as T. Hemmert's
[`key-recovery-mceliece-tii-solutions`](https://github.com/tobhem/key-recovery-mceliece-tii-solutions): public keys, recovered secret keys, and one script that checks a recovered key against its public key.

**Five of these challenges were previously unsolved** (at least as far as we know) — they are absent from the Hemmert archive (which covers 83–248 but not 129, 213, 240, 246, or 252). Two further challenges (83 and 248) are included as reproduction controls: the same code reproduces keys Hemmert already published, which exercises the whole pipeline end to end against a known answer.


## Results

Originally (2023), the number labels in TII challenges referred to the "bit security" of the challenge, but this has been known to be inaccurate. As a highlight, we solved TII-252, a challenge originally labeled with 2<sup>252</sup> work factor -- in 6 minutes on a laptop system.

All seven keys are recovered and independently verified: the recovered support `x` and Goppa polynomial `g` reconstruct exactly the public parity-check row space over `GF(2^m)` (see *Verifying* below).

| Challenge | m | r | n | status | wall time | memory | system |
|-----------|---|---|------|--------|-----------|--------|--------|
| **TII-252** | 10 | 11 | 1008 | **new** | 6 min 15 s | 2.7 GiB | 12-core laptop |
| **TII-246** | 10 | 11 | 1009 | **new** | 3 min 11 s | 2.7 GiB | 12-core laptop |
| **TII-240** | 10 | 11 | 1010 | **new** | 3 min 06 s | 2.7 GiB | 12-core laptop |
| **TII-213** | 9 | 10 | 496 | **new** | 6 h 45 min | 144 GiB | 28-vCPU server |
| **TII-129** | 9 | 9 | 509 | **new** | 4 h 30 min | 80 GiB | 28-vCPU server |
| TII-248 | 9 | 7 | 482 | control | 13 min 38 s | 0.4 GiB | 12-core laptop |
| TII-83  | 8 | 5 | 253 | control | 24 s | 1.7 GiB | 12-core laptop |

`m` = field extension degree, `r` = Goppa degree (= `deg g`), `n` = code length (= `|support|`). *Wall time* and *memory* (peak resident set of the largest process) are measured on the stated **system**: the **12-core laptop** is an AMD Ryzen AI 9 HX 370 (12 cores / 24 threads, 30 GiB); the **28-vCPU server** is a larger-memory machine used only for the two recoveries whose working set exceeds 30 GiB (TII-129/213), whose keys are then re-verified on the laptop. Core counts follow the paper's convention of physical cores, not hardware threads. Every recovery reads the public key only, ends in `verified_recovery`, and re-derives the committed key; per-run records are in `timings/`.

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
  tii_129.txt … tii_252.txt   # new challenges (from ElenaKirshanova/tii_decoding_challenge)
  tii_83.txt  tii_248.txt     # controls (from the Hemmert archive)
tii_secret_keys/              # recovered keys, one self-describing JSON per challenge
  secret_key_tii_<N>.json     # support, Goppa poly, field modulus, parameters, provenance
verify_recovered_key.sage     # standalone SageMath verifier (no external dependencies)
timings/                      #  laptop verification + end-to-end run records
  tii_<N>_laptop_run.txt      # end-to-end recovery re-run here
  tii_<N>_verify.txt          # independent verification here
  tii_129/213_recovery.txt    # large-memory-machine recovery records
SOURCES.md                    # upstream URLs, pinned commit, and SHA-256 of every public key
```

A recovered key is stored as readable JSON rather than an opaque pickle. Each `secret_key_tii_<N>.json` carries the support and Goppa-polynomial coefficients as canonical `GF(2^m)` integers, the field-defining polynomial, the parameters `(m,r,n)`, the SHA-256 of the public key it was recovered against, and the attack provenance (parameters `p,s`, seed, code and Sage versions).

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

accepting the key iff `RowSpace(H_rec) == RowSpace(H)` over `GF(2^m)`. Comparing row spaces (not a particular echelon form) makes the check independent of how `H` was stored. The extension degree `m` and Goppa degree `r` are taken from the challenge parameters and checked, not re-derived from `g`, so a wrong parameter surfaces as a failure rather than being silently absorbed. All 13 checks must pass for a key to be reported `CORRECT`.


## Original challenge data

The public keys are verbatim copies of the upstream challenge files, bound to each recovered key by SHA-256. See **[SOURCES.md](SOURCES.md)** for the upstream repositories, the pinned commit, the full digest table, and how to re-fetch and re-check the originals. In short, the five new challenges come from the official TII challenge repository [`ElenaKirshanova/tii_decoding_challenge`](https://github.com/ElenaKirshanova/tii_decoding_challenge) (`public_keyRec/pk_McEliece_<N>.txt`), and the two controls from the Hemmert archive.

