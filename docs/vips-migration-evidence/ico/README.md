Previously, favicon conversion used ImageMagick to decode the final ICO frame.

This commit decodes that frame through the sandboxed native worker when `GlobalSetting.enable_vips_image_processing` is enabled, preserving palette colors, transparency, and PNG output.

The benchmark used source `da0c0d17db42e5b096a5c530700b3a33f607897a`. Exact source files, input hashes, raw timings, and output hashes are retained in [results.json](results.json) and [the standalone bundle](benchmark/).

Measurements ran on the designated Linux server (2 CPUs, 2 GiB RAM), as `discourse`, with Landlock enabled, in `discourse/base:2.0.20260812-0036` at `sha256:837e8ed4b5916baa36856b842ad84fe262b6b1b5550701f8844b13cc7acad7a5`. This is the official launcher default image; its match to the deployed production image remains unconfirmed. Runtime: Ruby 3.4.10, libvips 8.18.4, ImageMagick 7.1.2-27 Q16-HDRI.

Warm timings alternate the two backends over 31 iterations per sample and include the real wrapper, IPC, sandbox child, and codec operation. Rails boot is excluded. These are operation timings, not complete upload or page-generation timings.

Thirteen inputs accepted by both decoders have identical decoded channels, including alpha. The corpus covers BMP 1/4/8/24/32-bit frames, PNG frames, final-frame selection, 5-pixel-wide AND masks, and a 1×1 icon. The truncated bitmap fails in both backends. RGB555 is accepted by GdkPixbuf but rejected by ImageMagick; it is an acceptance change, not a comparable successful conversion. The native GdkPixbuf dependency and its ICO loader must be present in the deployment image.

| Sample | ImageMagick median / p95 (ms) | libvips median / p95 (ms) | Median change | Output evidence |
| --- | ---: | ---: | ---: | --- |
| `ico-bmp-16bit.ico` | 34.84 / 44.54 | 34.18 / 43.38 | Not comparable | IM rejects; native accepts; outcomes differ |
| `ico-bmp-1bit.ico` | 30.46 / 40.30 | 43.03 / 58.32 | +41.2% | Decoded pixels identical |
| `ico-bmp-24bit.ico` | 32.25 / 37.56 | 34.20 / 40.60 | +6.0% | Decoded pixels identical |
| `ico-bmp-32bit.ico` | 27.93 / 32.55 | 29.96 / 33.03 | +7.3% | Decoded pixels identical |
| `ico-bmp-4bit.ico` | 31.96 / 39.47 | 33.98 / 39.48 | +6.3% | Decoded pixels identical |
| `ico-bmp-8bit.ico` | 31.52 / 37.83 | 33.56 / 38.50 | +6.5% | Decoded pixels identical |
| `ico-last-bmp.ico` | 32.30 / 38.45 | 30.59 / 33.45 | -5.3% | Decoded pixels identical |
| `ico-last-png.ico` | 30.96 / 35.76 | 31.34 / 38.27 | +1.2% | Decoded pixels identical |
| `ico-odd-mask-1bit.ico` | 37.58 / 65.94 | 59.62 / 87.73 | +58.6% | Decoded pixels identical |
| `ico-odd-mask-24bit.ico` | 39.82 / 61.31 | 43.53 / 66.81 | +9.3% | Decoded pixels identical |
| `ico-odd-mask-4bit.ico` | 35.81 / 44.36 | 36.93 / 44.77 | +3.1% | Decoded pixels identical |
| `ico-odd-mask-8bit.ico` | 33.96 / 39.70 | 35.92 / 43.28 | +5.8% | Decoded pixels identical |
| `ico-png-alpha.ico` | 33.76 / 40.54 | 34.76 / 39.44 | +2.9% | Decoded pixels identical |
| `ico-truncated-bitmap.ico` | 36.35 / 43.91 | 26.99 / 31.45 | Error paths only | Both reject; error timing |
| `smallest.ico` | 34.89 / 40.54 | 36.23 / 43.78 | +3.8% | Decoded pixels identical |

Positive median changes are regressions. Five fresh-worker calls measured 239.79–259.88 ms (median 252.72 ms). These calls include conversion plus worker startup; they are not a measurement of startup alone, and no paired cold ImageMagick comparison was recorded.

Most successful ICO cases are slower in this run, particularly the 1-bit inputs. Encoded PNG bytes differ despite identical decoded pixels. Error-path timings and the newly accepted RGB555 case must not be included in a successful-conversion speedup claim.

| Production case | ImageMagick | libvips |
| --- | --- | --- |
| `ico-bmp-16bit.ico` | Rejects RGB555; no output | ![libvips ico-bmp-16bit.ico](outputs/ico-bmp-16bit.ico-libvips.png) |
| `ico-bmp-1bit.ico` | ![imagemagick ico-bmp-1bit.ico](outputs/ico-bmp-1bit.ico-imagemagick.png) | ![libvips ico-bmp-1bit.ico](outputs/ico-bmp-1bit.ico-libvips.png) |
| `ico-bmp-24bit.ico` | ![imagemagick ico-bmp-24bit.ico](outputs/ico-bmp-24bit.ico-imagemagick.png) | ![libvips ico-bmp-24bit.ico](outputs/ico-bmp-24bit.ico-libvips.png) |
| `ico-bmp-32bit.ico` | ![imagemagick ico-bmp-32bit.ico](outputs/ico-bmp-32bit.ico-imagemagick.png) | ![libvips ico-bmp-32bit.ico](outputs/ico-bmp-32bit.ico-libvips.png) |
| `ico-bmp-4bit.ico` | ![imagemagick ico-bmp-4bit.ico](outputs/ico-bmp-4bit.ico-imagemagick.png) | ![libvips ico-bmp-4bit.ico](outputs/ico-bmp-4bit.ico-libvips.png) |
| `ico-bmp-8bit.ico` | ![imagemagick ico-bmp-8bit.ico](outputs/ico-bmp-8bit.ico-imagemagick.png) | ![libvips ico-bmp-8bit.ico](outputs/ico-bmp-8bit.ico-libvips.png) |
| `ico-last-bmp.ico` | ![imagemagick ico-last-bmp.ico](outputs/ico-last-bmp.ico-imagemagick.png) | ![libvips ico-last-bmp.ico](outputs/ico-last-bmp.ico-libvips.png) |
| `ico-last-png.ico` | ![imagemagick ico-last-png.ico](outputs/ico-last-png.ico-imagemagick.png) | ![libvips ico-last-png.ico](outputs/ico-last-png.ico-libvips.png) |
| `ico-odd-mask-1bit.ico` | ![imagemagick ico-odd-mask-1bit.ico](outputs/ico-odd-mask-1bit.ico-imagemagick.png) | ![libvips ico-odd-mask-1bit.ico](outputs/ico-odd-mask-1bit.ico-libvips.png) |
| `ico-odd-mask-24bit.ico` | ![imagemagick ico-odd-mask-24bit.ico](outputs/ico-odd-mask-24bit.ico-imagemagick.png) | ![libvips ico-odd-mask-24bit.ico](outputs/ico-odd-mask-24bit.ico-libvips.png) |
| `ico-odd-mask-4bit.ico` | ![imagemagick ico-odd-mask-4bit.ico](outputs/ico-odd-mask-4bit.ico-imagemagick.png) | ![libvips ico-odd-mask-4bit.ico](outputs/ico-odd-mask-4bit.ico-libvips.png) |
| `ico-odd-mask-8bit.ico` | ![imagemagick ico-odd-mask-8bit.ico](outputs/ico-odd-mask-8bit.ico-imagemagick.png) | ![libvips ico-odd-mask-8bit.ico](outputs/ico-odd-mask-8bit.ico-libvips.png) |
| `ico-png-alpha.ico` | ![imagemagick ico-png-alpha.ico](outputs/ico-png-alpha.ico-imagemagick.png) | ![libvips ico-png-alpha.ico](outputs/ico-png-alpha.ico-libvips.png) |
| `ico-truncated-bitmap.ico` | Rejects truncated bitmap; no output | Rejects truncated bitmap; no output |
| `smallest.ico` | ![imagemagick smallest.ico](outputs/smallest.ico-imagemagick.png) | ![libvips smallest.ico](outputs/smallest.ico-libvips.png) |

The switch remains default-off. These artifacts describe the measured source snapshot; they do not establish that the final PR head passes tests or CI. Final source alignment, targeted regression tests, lint at push time, and PR CI remain pending. Supplemental `local-dv/` artifacts retain their original paths and environment details and are not production timings.

Review source: `tgxworld/vips-review-06-ico`, base `36b59fd34321fd60fbfa23af9a97b9754a86fe47`, head `a29087e9804520698437ca32cbfd7888749d96a4`. Source commits: `da0c0d17db42e5b096a5c530700b3a33f607897a`, `5bba606a5d2326d30cf31f68224839cd394d73b5`. The complete operation stack is recorded in [review-stack-manifest.json](../review-stack-manifest.json). Benchmark snapshots and extracted review heads have separate identities; measured results do not imply that this exact head passed tests or CI.
