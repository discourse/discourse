This companion applies the unchanged FileHelper optimizer stage to the final encoded backend pairs. It does not rerun transformation timing, Rails upload admission, file adoption, or persistence. Existing `pairs.json` and `outputs/results.json` remain historical; use fresh final manifest and output paths.

The collector reads the recorded result files and verifies each selected encoded output against its original SHA-256. It selects the corrected SVG rows before touching output files, so the remote geometry directory can contain final SVG outputs alongside unchanged raster outputs. The archived pre-white geometry bundle is not needed for this stage. Decoded previews, cold files, historical duplicates, failed transforms, and JPEG's unpaired stress attempt are excluded and recorded explicitly in an audit JSON file.

Source selection:

| Operation | Raw report | Outputs |
| --- | --- | --- |
| JPEG conversion | `jpeg/final-selective.json` | `jpeg/outputs-final-selective` |
| Orientation | `orientation/final-selective-corrected.json` | `orientation/outputs-final-selective` |
| Downsize raster | `geometry/downsize-final-selective.json` | recorded encoded paths under `geometry/outputs/downsize` |
| Downsize SVG | `geometry/downsize-svg-white.json` | replaces only the matching old SVG row |
| Crop raster | `geometry/crop-final-selective.json` | recorded encoded paths under `geometry/outputs/crop` |
| Crop SVG | `geometry/crop-svg-white-false.json`, `geometry/crop-svg-white-true.json` | replaces only the matching old SVG rows |
| Resize | `geometry/resize-final-white.json` | recorded encoded paths under `geometry/outputs/resize` |

The existing-output local audit verifies 141 pairs: JPEG 12, downsize 33, crop 40, resize 56. Corrected orientation was unavailable in the local source copy during preparation; the final remote collector requires it. Do not use the local `--allow-pending-orientation` escape hatch for the final run. The final audit file records the actual count and selected report hashes.

`run.rb` now accepts orientation with UploadCreator's default `allow_pngquant=false`, checks collected input hashes before copying, and records transform provenance alongside each optimizer result. Each original pair is optimized under both metadata settings. For crop and resize, this includes cross-mode combinations in addition to the matching transform/optimizer mode; use the recorded transform mode when assessing actual caller behavior. These direct-stage comparisons are not complete caller results.

No selected original geometry PNG currently reaches 500,000 bytes. The eight larger existing PNGs are decoded JPEG previews, not geometry transform outputs, and are excluded. Real PNG outputs below 500,000 bytes exercise `allow_pngquant=true`; the supplementary case below covers `allow_pngquant=false` at or above the boundary. Actual optimizer subprocess events still need inspection: the setting alone does not prove a worker executed.

Coordinator commands for existing output pairs, on the remote host after copying the updated collector and runner into the existing optimizer directory:

```sh
bench_root=/root/discourse-vips-migration-01a0846e
python3 "$bench_root/optimizer/collect_final_pairs.py" \
  --jpeg-root "$bench_root/jpeg" \
  --geometry-root "$bench_root/geometry" \
  --orientation-root "$bench_root/orientation" \
  --output "$bench_root/optimizer/pairs-final.json"
```

Use the existing pinned Linux optimizer environment with `/root/discourse-vips-migration-01a0846e` mounted at `/benchmark-sources`, its installed optimizer dependencies, and working directory `/benchmark-sources/optimizer`:

```sh
bundle exec ruby run.rb pairs-final.json outputs-final-c63
```

The collector refuses to overwrite a manifest/audit. The runner preserves original source images but does not refuse an existing output directory; the coordinator must use the fresh `outputs-final-c63` path once. Do not reuse historical `outputs`.

The threshold supplement creates one deterministic 1024×768 opaque RGB-noise PNG with Ruby seed 20260909. It executes the final c63 downsize at 75%, crop at 768×576 in both metadata modes, and resize at 768×576 in both modes, once per backend. These are five genuine geometry output pairs, with no transformation timing claim. It checks source hashes, Landlock, exact output dimensions, output hashes, and that every output is at least 500,000 bytes. Input generation uses one bounded 2.36 MB byte string rather than a large Ruby pixel array.

Run this command in the existing geometry dependency environment with the same task root mount; the geometry directory must permit the existing worker's temporary socket directory. The supplement refuses an existing threshold output directory:

```sh
GEOMETRY_ROOT=/benchmark-sources/geometry \
BUNDLE_GEMFILE=/benchmark-sources/geometry/Gemfile \
  bundle exec ruby /benchmark-sources/optimizer/prepare_threshold_pairs.rb \
  /benchmark-sources/optimizer/threshold-final-c63
```

Inspect `threshold-results.json`: all five statuses must be `ok`, both outputs must meet the size threshold, and dimensions must be 768×576. The script exits nonzero on any failure. No runtime execution or threshold-size success is claimed by this preparation.

Then collect only the supplement on the host, avoiding duplicate optimization of the final main corpus:

```sh
bench_root=/root/discourse-vips-migration-01a0846e
python3 "$bench_root/optimizer/collect_final_pairs.py" \
  --threshold-only \
  --threshold-root "$bench_root/optimizer/threshold-final-c63" \
  --output "$bench_root/optimizer/pairs-threshold-final.json"
```

Back in the existing optimizer environment:

```sh
bundle exec ruby run.rb pairs-threshold-final.json outputs-threshold-final-c63
```

Review the returned cases and errors individually. Confirm `allow_pngquant=false` for every supplementary backend and no pngquant command events, while eligible small geometry PNGs in the main corpus exercise the other branch. Record metadata stripping, ICC/EXIF/XMP/IPTC and PNG chunks, optimizer return values, subprocess results, and normalized visible differences. Keep both final results separate from the historical optimizer results. No benchmark speedup claim belongs to this untimed companion.
