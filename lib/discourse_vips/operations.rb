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

        thumbnail = Vips::Image.thumbnail(input_path, 1, height: 1, size: :force)
        components = thumbnail.getpoint(0, 0).map(&:round)
        components = [components.first] * 3 if thumbnail.bands < 3
        format("%02X%02X%02X", *components.first(3))
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
    end
  end
end
