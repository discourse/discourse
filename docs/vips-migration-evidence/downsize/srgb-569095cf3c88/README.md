# Downsize sRGB evidence

Measured combined-stack source: `569095cf3c8800179c6dd8219c428f6d6cacf2ca`. 16 cases, two backends, 101 warm timing calls and 101 separate memory calls per case. Actual OptimizedImage.downsize entrypoint including shared FileHelper post-processing; only enable_vips_image_processing changes. Source fingerprints and every measurement are in results.json.

JPEG and PNG from Codec Corpus `8e10d4d765667c1c49d74413878fc4bfb46dcf8d`. GIF, WebP and AVIF use the PNG encoded with native libvips defaults. Display P3 variant uses icc_transform(p3, input_profile: srgb). Exact provenance, dimensions and hashes recorded.

Libvips thumbnail converts to built-in sRGB. JPEG/PNG/GIF encoding explicitly disables interlace. Metadata stripping: True.

Memory: process-tree smaps_rollup RSS/PSS at 1 ms intervals; extra memory is peak minus per-call idle, clipped at zero. Short peaks may be missed. Worker idle medians: 29.65 MiB RSS / 15.94 MiB PSS, excluded from extra memory. Warm worker PID remains constant across all cases. Owned DV Rails/Ember remain running; no fixed CPU/memory caps.

Reproduce with NATIVE_OPERATION=downsize, SOURCE_HEAD and SOURCE_SHA256 from results.json, using bin/rails runner benchmark.rb.
