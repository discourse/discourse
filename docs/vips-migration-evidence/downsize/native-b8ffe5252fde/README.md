# Native downsize evidence

Source: `b8ffe5252fde0090db6183777919daa5d1691d86`. 39 unique inputs, 57 cases, two backends.

The first 30 inputs use the same pinned Codec Corpus selection as PR #43463. Geometry rotates through `50%`, `100x100>`, and `10000@` across that selection. Nine repository fixtures each exercise all three targets, covering GIF, WebP, AVIF, animation, transparency, 16-bit alpha, and EXIF orientation 6. Downsizing preserves format; SVG-to-PNG conversion is outside this operation.

The actual `OptimizedImage.downsize` entry point runs for both backends. Only `GlobalSetting.enable_vips_image_processing` changes. Each call uses an unchanged input and a separate output path that is overwritten across samples; in-place replacement is covered by specs. Shared FileHelper post-processing is included. Native libvips loader, thumbnail/resize, rounding, saver defaults are retained. As documented for resize, alpha inputs use premultiply/resize/unpremultiply and cast back to the original band format; no custom alpha arithmetic is used.

Timing: median of 101 runs, excluding Rails startup. Memory: separate 101 runs with process-tree RSS and PSS sampled by reading smaps_rollup, with a 1 ms pause between samples. Short peaks can be missed. Extra memory is peak minus the idle level before each call, clipped at zero. The same warm libvips worker is verified across every conversion; the script waits for conversion children to exit between memory runs. Worker idle medians across 57 case medians: 30.34 MiB RSS, 22.60 MiB PSS. That fixed cost is excluded from extra-memory values.

The session DV retains Rails and Ember services. It has no fixed CPU or memory limit. See environment.json for image identity and results.json for versions, source fingerprints, inputs, complete timing and memory distributions, bytes, dimensions, and checksums.

All 57 cases succeed for both backends. Native bounding-box rounding gives 100x66 for rgb.jpg, where ImageMagick gives 100x67.

manifest.json verifies every copied input and output hash, every successful case's 101 timing/101 memory samples, and the stable worker PID.

Run the accompanying benchmark.rb with bin/rails runner, using the exact source checkout and the source_head and source_sha256 values from results.json as SOURCE_HEAD and SOURCE_SHA256 environment variables. BENCHMARK_ITERATIONS and BENCHMARK_MEMORY_ITERATIONS default to 101. BENCHMARK_FILTER optionally selects a case-ID substring for a focused rerun.

## Visual verification

All 57 comparisons were inspected in 15 captured sections; all 171 images decoded with zero broken images. The static comparison.html uses the original immutable files. The screenshot gallery includes every geometry, including the additional fixture cases. This is a visual sanity check, not a perceptual-quality metric.

- [Cases 1–4](screenshots/batch-1.png)
- [Cases 5–8](screenshots/batch-2.png)
- [Cases 9–12](screenshots/batch-3.png)
- [Cases 13–16](screenshots/batch-4.png)
- [Cases 17–20](screenshots/batch-5.png)
- [Cases 21–24](screenshots/batch-6.png)
- [Cases 25–28](screenshots/batch-7.png)
- [Cases 29–32](screenshots/batch-8.png)
- [Cases 33–36](screenshots/batch-9.png)
- [Cases 37–40](screenshots/batch-10.png)
- [Cases 41–44](screenshots/batch-11.png)
- [Cases 45–48](screenshots/batch-12.png)
- [Cases 49–52](screenshots/batch-13.png)
- [Cases 53–56](screenshots/batch-14.png)
- [Cases 57–57](screenshots/batch-15.png)
