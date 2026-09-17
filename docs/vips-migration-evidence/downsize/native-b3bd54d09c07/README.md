# Thumbnail downsize evidence

Source: `b3bd54d09c07a911eebec72644e0b52b9e171899`. Five unique inputs, 15 cases, two backends. JPEG rgb.jpg and PNG 1025469.png come from Codec Corpus pinned at 8e10d4d765667c1c49d74413878fc4bfb46dcf8d. GIF, WebP and AVIF are encoded from that PNG with documented Vips::Image.write_to_file using native defaults. Input generation is included in benchmark.rb. Each format exercises scale 0.5, bounds 100x100 and area 10000 pixels.

Measurements run OptimizedImage.downsize with only the global backend flag changing, including shared post-processing. Inputs remain unchanged; outputs are overwritten per sample. Libvips uses thumbnail with native encoder defaults. Timing medians use 101 runs; memory medians use 101 separate runs, sampling process-tree RSS/PSS via smaps_rollup every 1 ms. Extra memory is peak minus per-call idle, clipped at zero. Short peaks may be missed. The same warm worker PID is verified across all cases. Median worker idle: 29.53 MiB RSS, 14.88 MiB PSS, excluded from extra memory.

Rails and Ember remain running in the session DV; no fixed CPU/memory limits. environment.json records environment details; results.json records source fingerprints, versions and every sample. manifest.json contains hashes for all inputs and outputs. All 15 cases succeed for both backends.

Run benchmark.rb with bin/rails runner on the pinned source, supplying SOURCE_HEAD and SOURCE_SHA256 from results.json. Timing and memory iteration counts default to 101.
