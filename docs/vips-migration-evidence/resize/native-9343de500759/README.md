# Native resize evidence

Measured source: `9343de5007596d8318e9e26e3a912ae404466d31`. Five inputs, five cases, two backends. JPEG and PNG come from Codec Corpus pinned at `8e10d4d765667c1c49d74413878fc4bfb46dcf8d` (paths and hashes in results.json). GIF, WebP and AVIF are encoded from the PNG with Vips::Image.write_to_file using native defaults. Each image is scaled to cover 100×50, then center-cropped.

Measurements execute OptimizedImage.resize with only enable_vips_image_processing changing. Shared FileHelper post-processing is included. Source inputs remain unchanged; each output is overwritten. Native encoder defaults are used. Metadata stripping: True.

Timing medians: 101 warm calls. Memory medians: 101 separate calls, process-tree RSS/PSS from smaps_rollup sampled every 1 ms. Extra memory is peak minus per-call idle, clipped at zero. Short peaks may be missed. The warm worker PID is verified across all cases. Worker idle medians: 29.09 MiB RSS / 14.51 MiB PSS, excluded from extra memory.

Session DV Rails and Ember remain running; no fixed CPU or memory limits. environment.json records the environment. results.json includes source fingerprints and all samples. manifest.json hashes every image. Both backends succeed in every case; outputs need not be pixel-identical.

Reproduce on the pinned source using bin/rails runner benchmark.rb, with NATIVE_OPERATION=resize, SOURCE_HEAD and SOURCE_SHA256 from results.json. Iteration counts default to 101.
