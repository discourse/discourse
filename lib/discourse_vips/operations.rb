# frozen_string_literal: true

require "vips"
raise LoadError, "libvips 8.13 or newer is required" if !Vips.at_least_libvips?(8, 13)

module DiscourseVips
  module Operations
    DOMINANT_COLOR_LOADERS = %w[
      VipsForeignLoadJpeg
      VipsForeignLoadPng
      VipsForeignLoadNsgif
      VipsForeignLoadWebp
      VipsForeignLoadHeif
      VipsForeignLoadJxl
    ].freeze
    private_constant :DOMINANT_COLOR_LOADERS

    MAX_DIRECT_RESIZE_FACTOR = 256
    private_constant :MAX_DIRECT_RESIZE_FACTOR

    class << self
      def version
        block_loaders
        Vips.version_string
      end

      def generate_letter_avatar(markup:, font:, font_path:, background_color:, output_path:)
        block_loaders

        text = Vips::Image.text(markup, font:, dpi: 72, fontfile: font_path, rgba: true)
        canvas =
          text.gravity(:centre, 360, 360, extend: :background, background: [*background_color, 255])
        canvas.flatten(background: background_color).pngsave(output_path, compression: 6)
        nil
      end

      def resize_letter_avatar(input_path:, output_path:, size:)
        block_loaders(allowed: ["VipsForeignLoadPng"])

        thumbnail =
          Vips::Image.thumbnail(input_path, size, height: size, size: :both, crop: :centre)
        thumbnail.sharpen(sigma: 0.5, m1: 0.7).pngsave(
          output_path,
          palette: true,
          Q: 100,
          compression: 6,
          strip: true,
        )
        nil
      end

      def dominant_color(input_path:)
        block_loaders(allowed: DOMINANT_COLOR_LOADERS)

        loader = Vips.vips_foreign_find_load(input_path)
        raise Vips::Error, "unsupported input format" if loader.nil?

        options = { access: :sequential, fail_on: :none }
        options[:thumbnail] = false if loader == "VipsForeignLoadHeifFile"
        image = Vips::Image.new_from_file(input_path, **options)
        validate_dominant_color_image(image)

        sample_max = image.format == :ushort ? 65_535.0 : 255.0
        resize_input = image.cast(:double)
        resize_input = resize_input.premultiply(max_alpha: sample_max) if image.has_alpha?
        pixel = resize_to_pixel(resize_input, has_alpha: image.has_alpha?)
        pixel = pixel.unpremultiply(max_alpha: sample_max) if image.has_alpha?
        raise Vips::Error, "dominant color did not produce one pixel" if pixel.size != [1, 1]

        components = pixel.getpoint(0, 0)
        raise Vips::Error, "unable to read dominant color pixel" if components.length != image.bands

        red = quantize_sample(components[0], sample_max:)
        green = quantize_sample(image.bands < 3 ? components[0] : components[1], sample_max:)
        blue = quantize_sample(image.bands < 3 ? components[0] : components[2], sample_max:)
        format("%02X%02X%02X", red, green, blue)
      end

      def svg_to_png(input_path:, output_path:)
        block_loaders(allowed: ["VipsForeignLoadSvg"])

        Vips::Image.svgload(input_path).flatten.pngsave(output_path, compression: 9)
        nil
      end

      private

      def block_loaders(allowed: [])
        Vips.block_untrusted(true)
        Vips.block("VipsForeignLoad", true)
        Vips.block("VipsForeignLoadMagick", true)
        Vips.block("VipsForeignLoadMagick6", true)
        Vips.block("VipsForeignLoadMagick7", true)
        allowed.each { |loader| Vips.block(loader, false) }
      end

      def validate_dominant_color_image(image)
        max_dimension = ((2**31) - 1) / 7
        if image.width < 1 || image.height < 1 || image.width > max_dimension ||
             image.height > max_dimension
          raise Vips::Error, "unsupported image dimensions"
        end
        if !%i[uchar ushort].include?(image.format) || image.bands < 1 || image.bands > 4
          raise Vips::Error, "unsupported pixel format"
        end
      end

      def resize_to_pixel(image, has_alpha:)
        direct_resize =
          image.width <= MAX_DIRECT_RESIZE_FACTOR && image.height <= MAX_DIRECT_RESIZE_FACTOR
        if direct_resize && has_alpha
          image
            .embed(
              image.width * 3,
              image.height * 3,
              image.width * 7,
              image.height * 7,
              extend: :black,
            )
            .resize(1.0 / image.width, vscale: 1.0 / image.height, kernel: :lanczos3, gap: 0.0)
            .extract_area(3, 3, 1, 1)
        else
          image.resize(
            1.0 / image.width,
            vscale: 1.0 / image.height,
            kernel: :lanczos3,
            gap: direct_resize ? 0.0 : 2.0,
          )
        end
      end

      def quantize_sample(value, sample_max:)
        (value.clamp(0.0, sample_max) * 255.0 / sample_max + 0.5).floor
      end
    end
  end
end
