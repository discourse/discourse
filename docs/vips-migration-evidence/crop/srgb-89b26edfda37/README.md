# Crop sRGB evidence

Measured combined-stack source: `89b26edfda3709db6cd923bdd5494933a972b8bd`. 11 cases, two backends, 101 warm timing calls and 101 separate memory calls per case. Actual OptimizedImage.crop entrypoint including shared FileHelper post-processing; only enable_vips_image_processing changes. Source fingerprints and every measurement are in results.json.

JPEG and PNG from Codec Corpus `8e10d4d765667c1c49d74413878fc4bfb46dcf8d`. GIF, WebP and AVIF use the PNG encoded with native libvips defaults. Rectangular/small PNG variants use center extract_area on the same PNG, without stretching. Display P3 variant uses icc_transform(p3, input_profile: srgb). Exact provenance, dimensions and hashes recorded.

Libvips thumbnail converts to built-in sRGB. JPEG/PNG/GIF use native noninterlaced saver defaults. Metadata stripping: True.

Memory: process-tree smaps_rollup RSS/PSS at 1 ms intervals; extra memory is peak minus per-call idle, clipped at zero. Short peaks may be missed. Worker idle medians: 29.14 MiB RSS / 15.42 MiB PSS, excluded from extra memory. Warm worker PID remains constant across all cases. Owned DV Rails/Ember remain running; no fixed CPU/memory caps.

Reproduce with NATIVE_OPERATION=crop, SOURCE_HEAD and SOURCE_SHA256 from results.json, using bin/rails runner benchmark.rb.

Native thumbnail output is sharpened using Vips::Image.sharpen screen defaults. Magick resize retains its existing unsharp step; Magick downsize does not sharpen.
