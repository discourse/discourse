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

  def self.image_quality(input_path:, input_format:, timeout:)
    Client.call(
      ["image-quality", input_path, input_format],
      operation: :upload_quality_probe,
      timeout:,
    ).to_i
  end

  def self.animated?(input_path:, timeout:)
    Client.call(["animated", input_path], operation: :upload_animation_probe, timeout:)
  end

  def self.svg_dimensions(input_path:, timeout:)
    Client.call(["svg-dimensions", input_path], operation: :upload_svg_dimensions, timeout:)
  end

  def self.heif_to_jpeg(input_path:, output_path:, timeout:)
    Client.call(
      ["heif-to-jpeg", input_path, output_path],
      operation: :upload_format_conversion,
      timeout:,
    )
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

  def self.convert_to_jpeg(input_path:, output_path:, input_format:, quality:, timeout:)
    Client.call(
      ["convert-to-jpeg", input_path, output_path, input_format, quality],
      operation: :upload_format_conversion,
      timeout:,
    )
  end

  def self.auto_orient(input_path:, output_path:, source_quality:, timeout:)
    Client.call(
      ["auto-orient", input_path, output_path, source_quality],
      operation: :upload_auto_orient,
      timeout:,
    )
  end

  def self.before_fork
    Client.before_fork
  end

  def self.ico_to_png(input_path:, output_path:, timeout:)
    Client.call(
      ["ico-to-png", input_path, output_path],
      operation: :upload_format_conversion,
      timeout:,
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

  def self.downsize(
    input_path:,
    output_path:,
    input_format:,
    output_format:,
    geometry:,
    quality:,
    timeout:
  )
    Tempfile.create(["downsize-", ".#{output_format}"], File.dirname(output_path)) do |output|
      output.close
      Client.call(
        ["downsize", input_path, output.path, input_format, output_format, geometry, quality],
        operation: :optimized_image_downsize,
        timeout:,
        nice: 10,
      )
      File.rename(output.path, output_path)
    end
    nil
  end

  def self.crop(
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
    Tempfile.create(["crop-", ".#{output_format}"], File.dirname(output_path)) do |output|
      output.close
      Client.call(
        [
          "crop",
          input_path,
          output.path,
          input_format,
          output_format,
          width,
          height,
          quality,
          strip_metadata,
        ],
        operation: :optimized_image_crop,
        timeout:,
        nice: 10,
      )
      File.rename(output.path, output_path)
    end
    nil
  end
end
