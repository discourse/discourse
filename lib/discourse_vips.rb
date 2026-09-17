# frozen_string_literal: true

require_relative "discourse_vips/client"
require "tempfile"

module DiscourseVips
  SVG_DIMENSIONS_TIMEOUT_SECONDS = 3
  private_constant :SVG_DIMENSIONS_TIMEOUT_SECONDS

  SVG_TO_PNG_TIMEOUT_SECONDS = 3
  private_constant :SVG_TO_PNG_TIMEOUT_SECONDS

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

  def self.svg_to_png(
    input_path:,
    output_path:,
    read:,
    write:,
    timeout: SVG_TO_PNG_TIMEOUT_SECONDS,
    operation: :svg_to_png,
    nice: nil
  )
    timeout = [timeout, SVG_TO_PNG_TIMEOUT_SECONDS].min
    Client.call(
      ["svg-to-png", input_path, output_path],
      operation:,
      read: ["/etc/fonts", "/var/cache/fontconfig", *read],
      write:,
      timeout:,
      nice:,
    )
  end

  def self.downsize(
    input_path:,
    output_path:,
    timeout:,
    read:,
    write:,
    scale: nil,
    width: nil,
    height: nil,
    max_pixels: nil,
    strip_metadata: false
  )
    if [scale, width || height, max_pixels].compact.length != 1 || width.nil? != height.nil?
      raise ArgumentError,
            "provide exactly one resize target: scale, width and height, or max_pixels"
    end

    format = File.extname(input_path).delete_prefix(".").downcase
    raise ArgumentError, "unsupported format" if !%w[jpg jpeg png gif webp avif].include?(format)

    output_mode =
      File.exist?(output_path) ? File.stat(output_path).mode & 0o777 : 0o666 & ~File.umask

    Tempfile.create(["downsize-", ".#{format}"], File.dirname(output_path)) do |output|
      output.close
      Client.call(
        [
          "downsize",
          input_path,
          output.path,
          format,
          scale,
          width,
          height,
          max_pixels,
          strip_metadata,
        ],
        operation: :optimized_image_downsize,
        read:,
        write:,
        timeout:,
        nice: 10,
      )
      File.chmod(output_mode, output.path)
      File.rename(output.path, output_path)
    end
    nil
  end

  def self.resize(
    input_path:,
    output_path:,
    input_format:,
    output_format:,
    width:,
    height:,
    timeout:,
    read:,
    write:,
    quality: nil,
    strip_metadata: false
  )
    if !%w[jpg jpeg png gif webp avif svg].include?(input_format) ||
         !%w[jpg jpeg png gif webp avif].include?(output_format)
      raise ArgumentError, "unsupported format"
    end

    output_mode =
      File.exist?(output_path) ? File.stat(output_path).mode & 0o777 : 0o666 & ~File.umask

    Tempfile.create(["resize-", ".#{output_format}"], File.dirname(output_path)) do |output|
      output.close
      Client.call(
        ["resize", input_path, output.path, input_format, width, height, quality, strip_metadata],
        operation: :optimized_image_resize,
        read:,
        write:,
        timeout:,
        nice: 10,
      )
      File.chmod(output_mode, output.path)
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
    timeout:,
    read:,
    write:,
    quality: nil,
    strip_metadata: false
  )
    if !%w[jpg jpeg png gif webp avif svg].include?(input_format) ||
         !%w[jpg jpeg png gif webp avif].include?(output_format)
      raise ArgumentError, "unsupported format"
    end

    output_mode =
      File.exist?(output_path) ? File.stat(output_path).mode & 0o777 : 0o666 & ~File.umask

    Tempfile.create(["crop-", ".#{output_format}"], File.dirname(output_path)) do |output|
      output.close
      Client.call(
        ["crop", input_path, output.path, input_format, width, height, quality, strip_metadata],
        operation: :optimized_image_crop,
        read:,
        write:,
        timeout:,
        nice: 10,
      )
      File.chmod(output_mode, output.path)
      File.rename(output.path, output_path)
    end
    nil
  end

  def self.before_fork
    Client.before_fork
  end
end
