# Stock libvips image-processing migration

This matrix lists the Discourse runtime paths that use ImageMagick directly or through `OptimizedImage`. Test controls are not runtime paths.

ImageMagick stays installed during the change to the high-risk paths. A vips command failure does not start ImageMagick.

| Operation | Runtime paths | Input formats | ImageMagick behavior | Risk | Stock libvips behavior | Test evidence | Setting |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Letter-avatar generation and resize | `LetterAvatar.generate_fullsize`<br>`LetterAvatar.resize`<br>Preload in `lib/discourse.rb` | Discourse-generated SVG to PNG | Creates a colored canvas and a centered glyph. Creates each configured square size. | Low | Uses `vips flatten`, then `vips thumbnail` and tuned `vips sharpen`. | All avatar sizes and supported scripts<br>Opaque square output<br>Cache-key change | Always enabled in discourse/discourse#42150 |
| Dominant-color extraction | `Upload#calculate_dominant_color!` during upload creation and backfill | JPEG, PNG, GIF, WebP, AVIF, HEIC/HEIF, ICO-derived PNG, JPEG XL | Reduces the image to one 8-bit RGB pixel. Returns the color channels as a hexadecimal value. | Low | One `vips thumbnail` process writes one raw RGB pixel. | Color-depth and color-profile cases<br>Alpha and grayscale<br>Invalid or missing input<br>Backfill and scheduled job | Always enabled in discourse/discourse#42150 |
| Generated topic OG image | `TopicOgImageGenerator#render_png` | Discourse-generated SVG with sanitized image data URIs | Renders a fixed 1200×630 canvas. Then it optimizes the PNG. | Low | Uses `vips flatten`, then the existing PNG optimizer. | Dimensions<br>XML escaping<br>Raster and SVG images<br>Malformed nested SVG<br>No ImageMagick use | Always enabled in discourse/discourse#42150 |
| Optimized-image resize | `OptimizedImage.resize` and its callers | JPEG, PNG, first GIF/WebP/AVIF frame, converted HEIC/HEIF and ICO<br>SVG files are copied. | Applies orientation, fills the target, crops from the center, converts to sRGB, sharpens, and optimizes the output. | High | Uses `vips thumbnail`, tuned `vips sharpen`, saver options, and the existing optimizer. | Dimensions and aspect ratio<br>Orientation and transparency<br>Metadata and color profile<br>Format, image difference, and file size | `use_vips_for_image_processing` |
| Optimized-image north crop | `OptimizedImage.crop` for explicit cropped thumbnails | Same formats as optimized-image resize | Applies orientation, scales to cover, centers horizontally, crops from the north, converts to sRGB, and optimizes the output. | High | Uses `vips thumbnail`, `vips gravity` north, and tuned `vips sharpen`. | Portrait and landscape<br>Uncommon aspect ratios<br>Orientation and transparency<br>Crop geometry and image difference | `use_vips_for_image_processing` |
| Optimized-image downsize | `OptimizedImage.downsize` and its callers | JPEG, PNG, nonanimated GIF/WebP/AVIF, converted HEIC/HEIF and ICO | Applies orientation and the requested geometry. Keeps the output format. | High | Uses `vips thumbnail` with percentage, area, or shrink-only dimensions. | Percentage and area limits<br>Shrink-only behavior<br>Orientation and transparency<br>Format and file size | `use_vips_for_image_processing` |
| PNG/JPEG/HEIF encoding | `UploadCreator#execute_convert` through `convert_to_jpeg!` and `convert_heif!` | PNG, JPEG, HEIC, HEIF | Applies orientation and removes transparency. Keeps a PNG-to-JPEG result that meets both size limits. | High | Uses one `vips autorot` process with JPEG saver options. Keeps the metadata that stock libvips exposes. | White background for transparency<br>Orientation and dimensions<br>Quality and metadata<br>Existing size limits | `use_vips_for_image_processing` |
| ICO conversion | `UploadCreator#convert_favicon_to_png!` | ICO with PNG or DIB entries | Selects the last entry and keeps transparency. Stores the result as PNG. | High | Starts stock libvips directly. The operation fails because the hardened build has no ICO loader. | The disabled setting keeps the existing conversion.<br>The enabled setting returns the stock-libvips loader failure. | `use_vips_for_image_processing` |
| Orientation correction | `UploadCreator#fix_orientation!` | JPEG and other EXIF-oriented raster formats | Rewrites the pixels in the upright position. Resets the orientation. | High | Uses `vips autorot`. JPEG output uses the configured upload-image quality. | All EXIF orientations<br>Upright dimensions<br>Orientation reset<br>Output quality and metadata | `use_vips_for_image_processing` |
| Animated frame-count probe | `UploadCreator#animated?` after an inconclusive `FastImage` result | GIF, animated WebP, AVIF | Reads the frame count. Classifies counts of more than one as animated. | High | Reads `n-pages` with `vipsheader`. An absent field represents one page. | Static and animated GIF/WebP/AVIF<br>Malformed input<br>Animation-preserving upload paths | `use_vips_for_image_processing` |
| SVG dimension probe during upload | `UploadCreator#create_for` after `clean_svg!` | Sanitized SVG | Uses the internal ImageMagick SVG reader for pixel, physical-unit, and view-box dimensions. | High | Uses `vipsheader`, physical-unit conversion, and view-box values for zero dimensions. | Pixel and physical-unit dimensions<br>Zero dimensions<br>External-reference removal<br>Malformed SVG | `use_vips_for_image_processing` |
| Stored SVG dimension repair | `Upload#fix_dimensions!` | Sanitized SVG in local or external storage | Reads the width and height. A failed operation returns zero. | High | Uses the same stock-libvips SVG dimension probe as upload creation. | Local and downloaded SVG<br>Valid units<br>Malformed input<br>Zero after a failure | `use_vips_for_image_processing` |
| JPEG target-quality selection | `Upload#target_image_quality` during original and optimized-image encoding | JPEG | Estimates the source quality. Does not encode at a quality higher than the source quality. | High | Uses `jhead` to estimate the quality. Uses a lower configured target or the configured target for an absent estimate. | Lower-quality source<br>Higher-quality source<br>Malformed input<br>No ImageMagick use | `use_vips_for_image_processing` |
| Image optimizer sandbox limits | `lib/freedom_patches/image_optim_sandbox.rb` | Optimizer-managed PNG/JPEG output | Uses ImageMagick timeout and resource-limit constants. It does not start ImageMagick. | Infrastructure | Keeps the shared limits during this change. | Existing sandbox specs for the image optimizer | Future ImageMagick removal |
| ImageMagick runner, policy, health check, and exception | `lib/image_magick.rb`<br>`config/initializers/003-imagemagick.rb`<br>`config/imagemagick/policy.xml`<br>`ProblemCheck::ImageMagick`<br>`Discourse::ImageMagickMissing` | ImageMagick paths only | Restricts and checks ImageMagick while it stays available. | Infrastructure | Keeps ImageMagick for sites that use the disabled setting. | Existing ImageMagick runner, policy, and problem-check specs | Future ImageMagick removal |

## Format contract

The enabled setting uses the formats in the hardened stock-libvips build. The accepted formats stay the same where the current caller supports them.

ICO conversion is the exception. The stock build has no ICO loader. If an ICO upload requires conversion, the upload fails.

PNG-to-JPEG conversion keeps the metadata that libvips exposes. This metadata includes standard EXIF, XMP, and ICC data. Libvips does not expose legacy raw profiles or comments.

JPEG output uses `jhead` to estimate the source quality. The encoder does not use a nominal quality higher than the source quality.

This change does not add formats to `OptimizedImage`. TIFF stays outside `FileHelper.supported_images`. JPEG XL uploads do not get optimized images.

Discourse converts HEIC/HEIF uploads to JPEG before later transforms. Discourse copies optimized SVG images without a byte change.

Docker loader tests show that the stock build does not use ImageMagick or Ghostscript. Libvips marks the JPEG XL and SVG loaders as untrusted.

Only operations that need these formats enable the untrusted loaders. The sandbox, file allowlists, network block, timeouts, and resource limits stay active.

## Visual comparison contract

The resize, north-crop, and shrink-only tests decode both outputs to RGBA. The maximum normalized mean absolute channel error is `0.03`.

This limit permits differences from the encoders, resamplers, and antialiasing. It rejects visible errors in geometry, orientation, transparency, or color.

Both outputs must have the same dimensions. The libvips file size must stay between `0.5×` and `2×` the ImageMagick file size.

The orientation test permits an error of `0.10` because both processors encode the JPEG again. It also requires upright dimensions and a reset orientation.

## Cache contract

Letter avatars use the libvips fingerprint from discourse/discourse#42150. Optimized images use a different version for each image processor.

As a result, a setting change cannot reuse an artifact from the other image processor.
