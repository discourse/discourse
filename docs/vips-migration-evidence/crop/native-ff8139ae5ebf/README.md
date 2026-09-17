# Native crop evidence

Measured source: `ff8139ae5ebfa623684cef5393ba2469eaf0ebd0`. Five inputs, five cases, two backends. JPEG and PNG come from Codec Corpus pinned at `8e10d4d765667c1c49d74413878fc4bfb46dcf8d` (paths and hashes in results.json). GIF, WebP and AVIF are encoded from the PNG with Vips::Image.write_to_file using native defaults. Each image is scaled to cover 100×50, then top-centered cropped.

Measurements execute OptimizedImage.crop with only enable_vips_image_processing changing. Shared FileHelper post-processing is included. Source inputs remain unchanged; each output is overwritten. Native encoder defaults are used. Metadata stripping: True.

Timing medians: 101 warm calls. Memory medians: 101 separate calls, process-tree RSS/PSS from smaps_rollup sampled every 1 ms. Extra memory is peak minus per-call idle, clipped at zero. Short peaks may be missed. The warm worker PID is verified across all cases. Worker idle medians: 29.07 MiB RSS / 14.52 MiB PSS, excluded from extra memory.

Session DV Rails and Ember remain running; no fixed CPU or memory limits. environment.json records the environment. results.json includes source fingerprints and all samples. manifest.json hashes every image. Both backends succeed in every case; outputs need not be pixel-identical. ImageMagick GIF retains a 100×100 logical canvas after cropping; libvips writes 100×50. All other outputs are 100×50.

Reproduce on the pinned source using bin/rails runner benchmark.rb, with NATIVE_OPERATION=crop, SOURCE_HEAD and SOURCE_SHA256 from results.json. Iteration counts default to 101.
