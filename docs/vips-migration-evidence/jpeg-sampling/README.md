The final selective JPEG sampling policy preserves ordinary 4:4:4 and 4:2:0 sources, uses the encoder’s quality threshold for PNG sources, and emits full-chroma 4:4:4 for uncommon 4:2:2/4:4:0 sources. All 80 paired cases completed without backend errors or dimension mismatches. The uncommon-source policy avoids adding chroma loss on a second axis; it does not reproduce ImageMagick’s original sampling factors or guarantee matching pixels.

The [final report](final/final-selective.json), [runnable bundle](final/), [source manifest](final/source-manifest.json) and [verification record](verification.json) identify source `2ba8357019543403265a8b4cd24c906815484efe`. Its sampling paths are unchanged by the subsequent SVG-only fix in `c63ee831d4d2e332c466f1a272793eec94d9c22d`. All nine production source files match the recorded Git commit; all fourteen bundle/source hashes and all 160 JPEG output hashes, sizes, actual SOF dimensions and sampling factors were verified.

The coordinator ran the bundle as the unprivileged `discourse` user with Landlock on the designated Linux host, in `discourse/base:2.0.20260812-0036` at digest `sha256:837e8ed4b5916baa36856b842ad84fe262b6b1b5550701f8844b13cc7acad7a5`. A deployment-specific image override remains unconfirmed. The report records Ruby 3.4.10 and libvips 8.18.4. These are transformation compatibility measurements, without optimizer, caller adoption or timing measurements.

Each of five synthetic 96×64 sources contributes sixteen cases across resize, crop, downsize and JPEG conversion, with identity auto-orientation for JPEG inputs. PNG auto-orientation is excluded by the production input contract. Resize/crop cover both metadata modes and inferred, explicit 89 and explicit 90 quality; the exact per-operation cases appear in [the complete table](cases.md). All profiles are absent, so matching null ICC hashes do not establish profile preservation.

| Source | ImageMagick sampling | Native sampling | Maximum case mean RGB difference /255 | Maximum channel difference /255 | Native bytes relative to ImageMagick |
| --- | --- | --- | ---: | ---: | ---: |
| png | 420 at89;444 at90/92 | same | 2.685 | 17 | +48.9% to +102.8% |
| 444 | 444 | 444 | 2.887 | 16 | +49.6% to +103.3% |
| 420 | 420 | 420 | 2.428 | 12 | +46.7% to +69.3% |
| 422 | 422 | 444 | 33.152 | 126 | +71.6% to +126.3% |
| 440 | 440 | 444 | 3.351 | 21 | +59.5% to +157.2% |

The PNG threshold agrees for all sixteen cases; source 444/420 factors agree for all thirty-two ordinary JPEG cases. Source 422/440 intentionally becomes 444 in all thirty-two uncommon cases. Every native file in this small synthetic corpus is larger. The greatest discrepancy from ImageMagick is the 422 geometry group: up to mean 33.152/255 and maximum channel 126/255. Preserving more source chroma does not imply closer agreement with ImageMagick’s geometry output.

`exact_sampling_and_quality` combines actual sampling factors with ImageMagick’s estimated quality scalar. Those scalars are not encoder settings and need not agree: explicit native Q92 can be reported as 84. No estimated-quality parity is claimed.

The [earlier full-chroma experiment](experiments/full-chroma/outputs/results.json) also recorded source-relative comparisons for conversion and identity orientation. All thirty-two final uncommon-source output pairs and their inputs are byte-identical to the corresponding experimental artifacts. This links those specific pixel measurements to the final outputs; it does not validate forcing full chroma for ordinary 420 sources.

| Source / requested quality | Source-relative mean RGB error: ImageMagick | Source-relative mean RGB error: native | Native maximum channel error |
| --- | ---: | ---: | ---: |
| 422 / 89 | 8.855 | 0.715 | 3 |
| 422 / 90 | 8.727 | 0.583 | 3 |
| 440 / 89 | 0.224 | 0.567 | 3 |
| 440 / 90 | 0.914 | 0.485 | 3 |

Native 422 conversion retains the source colors more closely on these stripes. For 440, ImageMagick is closer at Q89 and native is closer at Q90; there is no universal fidelity advantage. These comparisons use decoded sRGB values, and are not a claim of perceptual equivalence on photographs.

The earlier common-policy artifacts remain under `final/outputs/results.json` and `final/history/pre-selective/`; the full-chroma experiment remains separate under `experiments/full-chroma/`. Their source identities are historical and must not be confused with the final selective worker.

Run a writable copy of `final/` as `/benchmark` in the same image, install its locked bundle and execute as the unprivileged `discourse` user:

```sh
cd /benchmark
bundle install
RESULT_PATH=/benchmark/rerun.json bundle exec ruby run.rb
```

The harness checks the source manifest, regenerates bounded synthetic inputs and overwrites that copy’s `outputs-final-selective/`. Retain the checked-in artifacts untouched. Final review-head alignment and CI remain the coordinator’s separate pending checks.
