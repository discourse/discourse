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
    Client.call(["dominant-color", input_path], operation: :upload_dominant_color, timeout:)
  end

  def self.before_fork
    Client.before_fork
  end
end
