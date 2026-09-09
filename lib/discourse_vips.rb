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

  def self.svg_dimensions(input_path:, timeout:)
    Client.call(["svg-dimensions", input_path], operation: :upload_svg_dimensions, timeout:)
  end

  def self.animated?(input_path:, timeout:)
    Client.call(["animated", input_path], operation: :upload_animation_probe, timeout:)
  end

  def self.svg_to_png(input_path:, output_path:, timeout:)
    Client.call(
      ["svg-to-png", input_path, output_path],
      operation: :topic_og_asset_render,
      timeout:,
    )
  end

  def self.topic_og_render(input_path:, output_path:, timeout:)
    Client.call(
      ["topic-og-render", input_path, output_path],
      operation: :topic_og_render,
      timeout:,
      nice: 10,
    )
  end

  def self.before_fork
    Client.before_fork
  end
end
