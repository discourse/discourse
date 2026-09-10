# frozen_string_literal: true

require_relative "discourse_vips/client"
require "tempfile"

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

  def self.resize(
    input_path:,
    output_path:,
    input_format:,
    output_format:,
    width:,
    height:,
    quality:,
    strip_metadata:,
    timeout:
  )
    Tempfile.create(["resize-", ".#{output_format}"], File.dirname(output_path)) do |output|
      output.close
      Client.call(
        [
          "resize",
          input_path,
          output.path,
          input_format,
          output_format,
          width,
          height,
          quality,
          strip_metadata,
        ],
        operation: :optimized_image_resize,
        timeout:,
        nice: 10,
      )
      File.rename(output.path, output_path)
    end
    nil
  end

  def self.before_fork
    Client.before_fork
  end
end
