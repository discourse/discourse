# frozen_string_literal: true

require_relative "discourse_vips/client"
require "image_processing/output_file"

module DiscourseVips
  SVG_DIMENSIONS_TIMEOUT_SECONDS = 3
  private_constant :SVG_DIMENSIONS_TIMEOUT_SECONDS

  SVG_TO_PNG_TIMEOUT_SECONDS = 3
  private_constant :SVG_TO_PNG_TIMEOUT_SECONDS

  def self.version
    Client.call(["version"], operation: :vips_version, read: [], write: [])
  end

  def self.letter_avatar(letter:, output_path:, background_color:, font:, font_path:)
    ImageProcessing::OutputFile.write(output_path) do |temporary_path|
      Client.call(
        ["letter-avatar", letter, temporary_path, background_color, font, font_path],
        operation: :letter_avatar_render,
        read: ["/etc/fonts", "/var/cache/fontconfig", font_path],
        write: [temporary_path],
      )
    end
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

  def self.heif_to_jpeg(input_path:, output_path:, quality:, timeout:)
    ImageProcessing::OutputFile.write(output_path) do |temporary_path|
      Client.call(
        ["heif-to-jpeg", input_path, temporary_path, quality],
        operation: :upload_heif_to_jpeg,
        read: [input_path],
        write: [temporary_path],
        timeout:,
      )
    end
  end

  def self.reencode_jpeg(input_path:, output_path:, quality:, timeout:)
    ImageProcessing::OutputFile.write(output_path) do |temporary_path|
      Client.call(
        ["reencode-jpeg", input_path, temporary_path, quality],
        operation: :upload_jpeg_reencoding,
        read: [input_path],
        write: [temporary_path],
        timeout:,
      )
    end
  end

  def self.png_to_jpeg(input_path:, output_path:, quality:, timeout:)
    ImageProcessing::OutputFile.write(output_path) do |temporary_path|
      Client.call(
        ["png-to-jpeg", input_path, temporary_path, quality],
        operation: :upload_png_to_jpeg,
        read: [input_path],
        write: [temporary_path],
        timeout:,
      )
    end
  end

  def self.svg_to_png(
    input_path:,
    output_path:,
    asset_paths: [],
    timeout: SVG_TO_PNG_TIMEOUT_SECONDS,
    operation: :svg_to_png,
    nice: nil
  )
    timeout = [timeout, SVG_TO_PNG_TIMEOUT_SECONDS].min
    ImageProcessing::OutputFile.write(output_path) do |temporary_path|
      Client.call(
        ["svg-to-png", input_path, temporary_path],
        operation:,
        read: [input_path, "/etc/fonts", "/var/cache/fontconfig", *asset_paths],
        write: [temporary_path],
        timeout:,
        nice:,
      )
    end
  end

  # Resizes an image and optionally changes its output format. Provide exactly one
  # resize target: width and height together, scale, or max_pixels.
  #
  # @param input_path [String] source image path.
  # @param output_path [String] destination path, which may equal input_path.
  #   An existing destination is preserved if processing fails.
  # @param timeout [Numeric] maximum processing time in seconds.
  # @param operation [Symbol] name recorded by image processing instrumentation.
  # @param input_format [String, nil] optional restriction on the detected input
  #   format. The decoder otherwise identifies the file from its contents.
  # @param output_format [String, nil] output format, defaulting to the destination
  #   extension. This can differ from the input format.
  # @param width [Integer, nil] target width in pixels, supplied with height.
  # @param height [Integer, nil] target height in pixels, supplied with width.
  # @param scale [Numeric, nil] alternative proportional resize factor.
  # @param max_pixels [Integer, nil] alternative maximum pixel area per frame.
  # @param size [Symbol] resize policy: :both allows enlargement and reduction,
  #   :up only enlarges, :down only reduces, and :force uses the exact dimensions.
  # @param crop [Symbol] cropping strategy for static thumbnails. Use :none, the
  #   default, for animations.
  # @param gravity [Symbol, nil] positions the resized image on the target canvas.
  #   For animations, each frame is positioned on its own canvas.
  # @param sharpen [Boolean] applies sharpening after resizing and positioning.
  # @param quality [Integer, nil] encoder quality when supported by the output format.
  # @param strip_metadata [Boolean] removes metadata when saving the image.
  # @param animated [Boolean] preserves GIF and WebP frames, frame delays and loop
  #   counts when true. Defaults to false, which processes only the first frame.
  # @return [nil]
  # @raise [ArgumentError] if resize targets conflict or are incomplete.
  # @raise [DiscourseVips::Error] if image processing fails or times out.
  def self.thumbnail(
    input_path:,
    output_path:,
    timeout:,
    operation:,
    input_format: nil,
    output_format: nil,
    width: nil,
    height: nil,
    scale: nil,
    max_pixels: nil,
    size: :both,
    crop: :none,
    gravity: nil,
    sharpen: false,
    quality: nil,
    strip_metadata: false,
    animated: false
  )
    if [scale, width || height, max_pixels].compact.length != 1 || width.nil? != height.nil?
      raise ArgumentError,
            "provide exactly one resize target: scale, width and height, or max_pixels"
    end

    ImageProcessing::OutputFile.write(output_path) do |temporary_path|
      Client.call(
        [
          "thumbnail",
          input_path,
          temporary_path,
          width,
          height,
          scale,
          max_pixels,
          size,
          crop,
          sharpen,
          quality,
          strip_metadata,
          gravity,
          input_format,
          output_format,
          animated,
        ],
        operation:,
        read: [input_path],
        write: [temporary_path],
        timeout:,
        nice: 10,
      )
    end
    nil
  end

  def self.before_fork
    Client.before_fork
  end
end
