class FileHelper
  def self.optimize_image!(filename, allow_pngquant: false)
    ImageProcessing::Instrumentation.instrument(operation: :image_optim) do
      image_optim(
        allow_pngquant: allow_pngquant,
        strip_image_metadata: SiteSetting.strip_image_metadata,
      ).optimize_image!(filename)
    end
  end

  def self.image_optim(allow_pngquant: false, strip_image_metadata: true)
    # memoization is critical, initializing an ImageOptim object is very expensive
    # sometimes up to 200ms searching for binaries and looking at versions
    memoize("image_optim", allow_pngquant, strip_image_metadata) do
      pngquant_options = false
      pngquant_options = { allow_lossy: true } if allow_pngquant

      ImageOptim.new(
        # GLOBAL
        timeout: 15,
        skip_missing_workers: true,
        # PNG
        oxipng: {
          level: 3,
          strip: strip_image_metadata,
        },
        optipng: false,
        advpng: false,
        pngcrush: false,
        pngout: false,
        pngquant: pngquant_options,
        # JPG
        jpegoptim: {
          strip: strip_image_metadata ? "all" : "none",
        },
        jpegtran: false,
        jpegrecompress: false,
        # Skip looking for gifsicle, svgo binaries
        gifsicle: false,
        svgo: false,
      )
    end
  end

  def self.memoize(*args)
    (@memoized ||= {})[args] ||= yield
  end

end
