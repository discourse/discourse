At integration commit `2ba8357019543403265a8b4cd24c906815484efe`, an independent read-only audit found no remaining production ImageMagick processing paths with the feature enabled except these quality probes:

- `Upload#target_image_quality`: `app/models/upload.rb:454`.
- `OptimizedImage.vips_quality`: `app/models/optimized_image.rb:383`.
- `UploadCreator#fix_orientation!`: `lib/upload_creator.rb:597`.

The audit covered core, plugins, scripts, direct CLI calls, and MiniMagick/RMagick bypasses. Other processing calls are confined to the disabled-feature path. Letter-avatar version/font calls also remain on that path. Configured image optimizers use separate binaries.

`app/services/problem_check/image_magick.rb:8` still checks executable availability when thumbnail creation is enabled. It does not process images. Once the quality probe is migrated, revisit whether this availability warning should apply with the native feature enabled.
