# frozen_string_literal: true

require_relative "discourse_vips/client"

module DiscourseVips
  SVG_DIMENSIONS_TIMEOUT_SECONDS = 3
  private_constant :SVG_DIMENSIONS_TIMEOUT_SECONDS

  def self.version
    Client.call(["version"], operation: :vips_version, read: [], write: [])
  end

  def self.letter_avatar(letter:, output_path:, background_color:, font:, font_path:)
    Client.call(
      ["letter-avatar", letter, output_path, background_color, font, font_path],
      operation: :letter_avatar_render,
      read: ["/etc/fonts", "/var/cache/fontconfig", font_path],
      write: [File.dirname(output_path)],
    )
  end

  def self.dominant_color(input_path:, timeout:)
    Client.call(
      ["dominant-color", input_path],
      operation: :upload_dominant_color,
      read: [input_path],
      write: [],
      timeout:,
      nice: 10,
    )
  end

  def self.svg_dimensions(input_path:, timeout:)
    timeout = [timeout, SVG_DIMENSIONS_TIMEOUT_SECONDS].min
    Client.call(
      ["svg-dimensions", input_path],
      operation: :upload_svg_dimensions,
      timeout:,
      read: [input_path],
      write: [],
    )
  end

  # Uses GIF/WebP frame counts and HEIF/AVIF image collections.
  # APNG and timed HEIF/AVIF sequences are unsupported.
  def self.animated?(input_path:, timeout:)
    Client.call(
      ["animated", input_path],
      operation: :upload_animation_probe,
      timeout:,
      read: [input_path],
      write: [],
    )
  end

  def self.heif_to_jpeg(input_path:, output_path:, quality:, timeout:, read:, write:)
    Client.call(
      ["heif-to-jpeg", input_path, output_path, quality],
      operation: :upload_heif_to_jpeg,
      read:,
      write:,
      timeout:,
    )
  end

  def self.reencode_jpeg(input_path:, output_path:, quality:, timeout:, read:, write:)
    Client.call(
      ["reencode-jpeg", input_path, output_path, quality],
      operation: :upload_jpeg_reencoding,
      timeout:,
      read:,
      write:,
    )
  end

  def self.png_to_jpeg(input_path:, output_path:, quality:, timeout:, read:, write:)
    Client.call(
      ["png-to-jpeg", input_path, output_path, quality],
      operation: :upload_png_to_jpeg,
      read:,
      write:,
      timeout:,
    )
  end

  def self.before_fork
    Client.before_fork
  end
end
