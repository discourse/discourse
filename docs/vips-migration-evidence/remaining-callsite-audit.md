At integration commit `a3c50521c64a57b149bb6c317449708ee06c0841`, all remaining production ImageMagick image-processing calls are confined to the disabled-feature path. The final audit covered core, plugins and scripts, including direct CLI, MiniMagick and RMagick bypasses.

The three previously outstanding quality callers now use the native worker: `Upload#target_image_quality`, `OptimizedImage.vips_quality`, and `UploadCreator#fix_orientation!`. The shared geometry selector preserves first-frame output encoding while the query retains whole-file metadata compatibility.

`UploadCreator#execute_convert` is reached only by the disabled ICO, JPEG and HEIF branches. OG render/assets, SVG dimensions, animation detection, orientation, and shared resize/crop/downsize each select the native branch when the flag is enabled. Letter-avatar generation and dominant-color processing predate this stack; their existing ImageMagick branches remain disabled with the flag on. Configured image optimizers use separate binaries.

`app/services/problem_check/image_magick.rb` still checks executable availability when thumbnail creation is enabled. It does not process images and is outside this processing migration. Historical ICO dominant-color exclusion also predates the base commit: the complete `Upload#calculate_dominant_color!` method is byte-identical to base `0708de39bcebe79c8469dfd88cd568c8e71b42c7`; see `ico-backfill-preexisting-proof.txt`.

This source audit establishes branch routing, not universal codec parity. Sample evidence, focused tests, independent review and each PR’s CI provide the separate behavior checks.
