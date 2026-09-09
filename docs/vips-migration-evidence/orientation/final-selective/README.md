# JPEG auto-orientation benchmark

This bundle snapshots the orientation worktree facade, worker, sandbox wrappers, and locked Ruby dependencies, then applies the two worker methods from the verified orientation fix recorded in the manifest. It does not include UploadCreator integration or a replacement JPEG-quality estimator.

Run inside the pinned production image recorded in `source-manifest.json`, with this directory as the working directory:

```sh
bundle check
RESULT_PATH="$PWD/results.json" bundle exec ruby boot.rb
```

The coordinator should provision the locked gems through the established benchmark environment if `bundle check` reports missing dependencies. The benchmark requires Landlock and the production image's `jpegtran` binary.

Each of the eleven inputs gets one warm-up and 31 timed transformations per backend, alternating backend order. ImageMagick runs the existing in-place `jpeg:input -auto-orient jpeg:input` command against a restored working copy. The libvips facade reads an unchanged input and writes a separate JPEG. Copying, source-quality estimation, validation, and output decoding occur outside the timed sections. Five additional samples include starting a fresh libvips worker, with the same representative photo and quality.

Eight color grids cover EXIF orientations 1–8. Their EXIF orientation segments are injected into the existing grid fixture without changing JPEG scan data. Photo and ICC samples come from the completed JPEG benchmark corpus. The progressive sample is produced before timing with `jpegtran -copy all -progressive`, preserving its coefficients and metadata.

Validation checks source hashes, output hashes, normalized orientation, expected dimensions, byte-identical ICC profiles, and all eight semantic color-grid layouts. Progressive encoding changes are recorded for each backend without assuming that either backend preserves the input encoding. Paired JPEG and independently decoded PNG outputs remain in `outputs/`; results record pixel differences and PSNR. The JPEG-quality argument is ImageMagick's source estimate, measured separately. An equal numeric encoder quality does not establish identical encoder behavior.

Rebuild the bundle from the owned source tree and the retained JPEG corpus:

```sh
python3 prepare_bundle.py --repo /tmp/discourse-vips-orientation-01a0846e --jpeg-benchmark /tmp/discourse-vips-migration-01a0846e/public/discourse-task/jpeg-benchmark
```

`cases.json` records seed hashes and generation recipes. `source-manifest.json` records source status, exact source-file hashes, boot and harness hashes, locked dependency hashes, and the intended production-image digest. Runtime validation rejects changes to those files. No production source is modified by preparation or benchmarking.
