# frozen_string_literal: true

require_relative "discourse_vips/client"

module DiscourseVips
  def self.version
    Client.call(["version"], operation: :vips_version)
  end

  def self.letter_avatar(letter:, output_path:, background_color:, font:, font_path:)
    Client.call(
      ["letter-avatar", letter, output_path, background_color, font, font_path],
      operation: :letter_avatar_render,
    )
  end

  def self.dominant_color(input_path:, timeout:)
    Client.call(
      ["dominant-color", input_path],
      operation: :upload_dominant_color,
      timeout:,
      nice: 10,
    )
  end

  # Uses GIF/WebP frame counts and HEIF/AVIF image collections.
  # APNG and timed HEIF/AVIF sequences are unsupported.
  def self.animated?(input_path:, timeout:)
    Client.call(["animated", input_path], operation: :upload_animation_probe, timeout:)
  end

  def self.heif_to_jpeg(input_path:, output_path:, timeout:)
    Client.call(
      ["heif-to-jpeg", input_path, output_path],
      operation: :upload_format_conversion,
      timeout:,
    )
  end

  def self.before_fork
    Client.before_fork
  end
end
