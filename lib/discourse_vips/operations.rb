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

    WARM_OPERATIONS = %w[text gravity flatten pngsave thumbnail].freeze
    private_constant :WARM_OPERATIONS

    module_function

    def warm
      WARM_OPERATIONS.each do |name|
        operation = Vips.vips_operation_new(name)
        raise "unable to initialize libvips operation #{name}" if operation.null?

        GObject.g_object_unref(operation)
      end
    end

    def call(command)
      operation, *arguments = command

      case operation
      when "version"
        Vips.version_string
      when "letter-avatar"
        letter_avatar(*arguments)
      when "dominant-color"
        dominant_color(*arguments)
      else
        raise ArgumentError, "unsupported libvips operation"
      end
    end

    def letter_avatar(letter, output_path, background_color, font, font_path)
      if !letter || !output_path || !font_path
        raise ArgumentError, "invalid letter avatar arguments"
      end
      raise ArgumentError, "font file does not exist" if !File.file?(font_path)
      raise ArgumentError, "invalid background color" if !background_color.match?(/\A\h{6}\z/)

      background = background_color.scan(/\h{2}/).map { |channel| Integer(channel, 16) }

      block_loaders
      markup = %(<span foreground="#ffffff" alpha="80%">#{letter}</span>)
      text = Vips::Image.text(markup, font:, dpi: 72, fontfile: font_path, rgba: true)
      canvas = text.gravity(:centre, 360, 360, extend: :background, background: [*background, 255])
      canvas.flatten(background:).pngsave(output_path, compression: 6)
      nil
    end

    def dominant_color(input_path)
      raise ArgumentError, "invalid dominant color arguments" if !input_path

      block_loaders(allowed: DOMINANT_COLOR_LOADERS)
      thumbnail = Vips::Image.thumbnail(input_path, 1, height: 1, size: :force)
      components = thumbnail.getpoint(0, 0).map(&:round)
      if thumbnail.has_alpha?
        alpha = components.pop / 255.0
        components.map! { |component| (component * alpha).round }
      end
      components = [components.first] * 3 if thumbnail.bands < 3
      format("%02X%02X%02X", *components.first(3))
    end

    def block_loaders(allowed: [])
      # https://github.com/libvips/libvips/issues/5174 could replace this loader policy.
      Vips.block_untrusted(true)
      Vips.block("VipsForeignLoad", true)
      Vips.block("VipsForeignLoadMagick", true)
      Vips.block("VipsForeignLoadMagick6", true)
      Vips.block("VipsForeignLoadMagick7", true)
      allowed.each { |loader| Vips.block(loader, false) }
    end
    private_class_method :letter_avatar, :dominant_color, :block_loaders
  end
end
