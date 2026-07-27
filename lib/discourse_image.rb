# frozen_string_literal: true

require "fastimage"
require "fileutils"
require "image_optim"
require "net/http"
require "pathname"
require "tempfile"
require "timeout"
require "uri"

class DiscourseImage
  class Error < StandardError
  end
  class InvalidImageError < Error
  end
  class UnsupportedFormatError < Error
  end
  class MetadataUnavailableError < Error
  end
  class ProcessingFailedError < Error
  end
  class TimeoutError < Error
  end

  IMAGE_TYPES = %i[avif bmp cur gif heic heif ico jpeg jxl png psd svg tiff webp].to_set.freeze
  TRANSFORM_TYPES = %i[avif gif ico jpeg png svg webp].to_set.freeze
  CONVERT_TYPES = (TRANSFORM_TYPES + %i[heic heif]).freeze
  OPTIMIZABLE_TYPES = %i[jpeg png].to_set.freeze
  LOSSY_TYPES = %i[avif jpeg webp].to_set.freeze
  ANIMATED_TYPES = %i[avif gif png webp].to_set.freeze
  ORIENTATIONS = {
    1 => :normal,
    2 => :flip_horizontal,
    3 => :rotate_180,
    4 => :flip_vertical,
    5 => :transpose,
    6 => :rotate_90,
    7 => :transverse,
    8 => :rotate_270,
  }.freeze
  SAFE_PATH_PATTERN = %r{\A[\w\-\./]+\z}m
  MAX_PNGQUANT_SIZE_BYTES = 500_000
  TRANSFORM_TIMEOUT_SECONDS = 20
  OPTIMIZE_TIMEOUT_SECONDS = 15

  private_constant :IMAGE_TYPES,
                   :TRANSFORM_TYPES,
                   :CONVERT_TYPES,
                   :OPTIMIZABLE_TYPES,
                   :LOSSY_TYPES,
                   :ANIMATED_TYPES,
                   :ORIENTATIONS,
                   :SAFE_PATH_PATTERN,
                   :MAX_PNGQUANT_SIZE_BYTES,
                   :TRANSFORM_TIMEOUT_SECONDS,
                   :OPTIMIZE_TIMEOUT_SECONDS

  # Determines the encoded image type from the source content.
  #
  # This inspects the image signature and does not trust a filename
  # extension. It does not fully validate or decode the image.
  #
  # @param source [String, Pathname, IO] a local path, HTTP/HTTPS URL,
  #   data URI, or readable binary IO
  # @param timeout [Numeric] maximum number of seconds spent reading the
  #   source; defaults to 2 seconds
  #
  # @return [Symbol] one of `:avif`, `:bmp`, `:cur`, `:gif`, `:heic`,
  #   `:heif`, `:ico`, `:jpeg`, `:jxl`, `:png`, `:psd`, `:svg`, `:tiff`,
  #   or `:webp`
  #
  # @raise [ArgumentError] if timeout is not positive
  # @raise [UnsupportedFormatError] if the image signature is not recognized
  # @raise [MetadataUnavailableError] if the source cannot be read or fetched
  # @raise [TimeoutError] if the deadline is exceeded
  #
  # @note Readable IO is rewound to position zero after inspection.
  def self.type(source, timeout: 2)
    with_metadata_errors(source, timeout: timeout) do |normalized_source|
      image_type = FastImage.type(normalized_source, timeout: timeout, raise_on_failure: true)
      raise UnsupportedFormatError if !IMAGE_TYPES.include?(image_type)

      image_type
    end
  end

  # Returns the intrinsic dimensions of an image.
  #
  # For raster images, these are the encoded pixel dimensions. For SVG
  # images, these are the width and height of the SVG viewport.
  #
  # @param source [String, Pathname, IO] a local path, HTTP/HTTPS URL,
  #   data URI, or readable binary IO
  # @param timeout [Numeric] maximum number of seconds spent reading the
  #   source; defaults to 2 seconds
  #
  # @return [Array<Integer>] a two-element `[width, height]` array containing
  #   positive pixel dimensions
  #
  # @raise [ArgumentError] if timeout is not positive
  # @raise [UnsupportedFormatError] if the image signature is not recognized
  # @raise [InvalidImageError] if positive dimensions cannot be determined
  # @raise [MetadataUnavailableError] if the source cannot be read or fetched
  # @raise [TimeoutError] if the deadline is exceeded
  #
  # @note Readable IO is rewound to position zero after inspection.
  def self.size(source, timeout: 2)
    with_metadata_errors(source, timeout: timeout) do |normalized_source|
      image_type = FastImage.type(normalized_source, timeout: timeout, raise_on_failure: true)
      raise UnsupportedFormatError if !IMAGE_TYPES.include?(image_type)

      local_path = local_source_path(source)
      dimensions =
        if image_type == :svg && local_path
          svg_dimensions(normalized_source, local_path, timeout: timeout)
        else
          FastImage.size(normalized_source, timeout: timeout, raise_on_failure: true)
        end
      if dimensions.blank? || dimensions.length != 2 ||
           dimensions.any? { |dimension| dimension.to_i <= 0 }
        raise InvalidImageError
      end

      dimensions.map(&:to_i)
    end
  end

  # Returns the transformation needed to display an image upright.
  #
  # Images without orientation metadata return `:normal`.
  #
  # @param source [String, Pathname, IO] a local path, HTTP/HTTPS URL,
  #   data URI, or readable binary IO
  # @param timeout [Numeric] maximum number of seconds spent reading the
  #   source; defaults to 2 seconds
  #
  # @return [Symbol] one of `:normal`, `:flip_horizontal`, `:rotate_180`,
  #   `:flip_vertical`, `:transpose`, `:rotate_90`, `:transverse`, or
  #   `:rotate_270`; rotations are clockwise
  #
  # @raise [ArgumentError] if timeout is not positive
  # @raise [UnsupportedFormatError] if the image signature is not recognized
  # @raise [InvalidImageError] if orientation metadata is malformed
  # @raise [MetadataUnavailableError] if the source cannot be read or fetched
  # @raise [TimeoutError] if the deadline is exceeded
  #
  # @note Readable IO is rewound to position zero after inspection.
  def self.orientation(source, timeout: 2)
    with_metadata_errors(source, timeout: timeout) do |normalized_source|
      image = FastImage.new(normalized_source, timeout: timeout, raise_on_failure: true)
      raise UnsupportedFormatError if !IMAGE_TYPES.include?(image.type)

      orientation = image.orientation
      ORIENTATIONS.fetch(orientation || 1) { raise InvalidImageError }
    end
  end

  # Determines whether an image contains animation.
  #
  # Animated GIF, PNG, WebP, and AVIF images return `true`. Recognized static
  # images return `false`.
  #
  # @param source [String, Pathname, IO] a local path, HTTP/HTTPS URL,
  #   data URI, or readable binary IO
  # @param timeout [Numeric] maximum number of seconds spent reading the
  #   source; defaults to 2 seconds
  #
  # @return [Boolean] whether the image is animated
  #
  # @raise [ArgumentError] if timeout is not positive
  # @raise [UnsupportedFormatError] if the image signature is not recognized
  # @raise [InvalidImageError] if animation status cannot be determined from
  #   a recognized animation-capable image
  # @raise [MetadataUnavailableError] if the source cannot be read or fetched
  # @raise [TimeoutError] if the deadline is exceeded
  #
  # @note Readable IO is rewound to position zero after inspection.
  def self.animated?(source, timeout: 2)
    with_metadata_errors(source, timeout: timeout) do |normalized_source|
      image = FastImage.new(normalized_source, timeout: timeout, raise_on_failure: true)
      image_type = image.type
      raise UnsupportedFormatError if !IMAGE_TYPES.include?(image_type)
      return false if !ANIMATED_TYPES.include?(image_type)

      animated = image.animated
      return animated if !animated.nil?

      local_path = local_source_path(source)
      raise InvalidImageError if local_path.nil?

      frame_count(local_path, image_type: image_type, timeout: timeout) > 1
    end
  end

  # Calculates the dominant color of an image.
  #
  # For an animated image, the first frame is used. Supported encodings are
  # AVIF, GIF, ICO, JPEG, PNG, and WebP.
  #
  # @param path [String, Pathname] an absolute local path to a raster image
  # @param timeout [Numeric] maximum processing time; defaults to 5 seconds
  #
  # @return [String] the 8-bit sRGB color as six uppercase hexadecimal
  #   characters without a leading `#`, such as `"6F745E"`
  #
  # @raise [ArgumentError] if timeout or the path type is invalid
  # @raise [Discourse::InvalidAccess] if the path is not absolute or safe
  # @raise [UnsupportedFormatError] if the file is not a supported raster image
  # @raise [InvalidImageError] if the image cannot be decoded
  # @raise [MetadataUnavailableError] if the file cannot be read
  # @raise [TimeoutError] if the deadline is exceeded
  def self.calculate_dominant_color(path, timeout: 5)
    input_path = validated_input_path(path)
    image_type = type(input_path)
    raise UnsupportedFormatError if !TRANSFORM_TYPES.include?(image_type) || image_type == :svg

    output =
      execute_command(
        "nice",
        "-n",
        "10",
        "convert",
        decoder_path(input_path, image_type, frame: :first),
        "-depth",
        "8",
        "-resize",
        "1x1",
        "-define",
        "histogram:unique-colors=true",
        "-format",
        "%c",
        "histogram:info:",
        timeout: timeout,
      )
    color = output[/#([0-9A-F]{6})/i, 1]
    raise InvalidImageError if color.nil?

    color.upcase
  rescue UnsupportedFormatError, InvalidImageError, MetadataUnavailableError, TimeoutError
    raise
  rescue ProcessingFailedError => error
    raise InvalidImageError, error.message
  end

  # Resizes an image while preserving its complete contents and aspect ratio.
  #
  # Exactly one sizing mode is required: `scale`, `maximum_pixels`, or one or
  # both dimension bounds. Animated images use their first frame. The stored
  # display orientation is applied before resizing. Supported inputs are AVIF,
  # GIF, ICO, JPEG, PNG, SVG, and WebP. Supported outputs are the same raster
  # formats, excluding SVG.
  #
  # @param input [String, Pathname] an absolute local input path
  # @param output [String, Pathname] an absolute local output path; its
  #   extension determines the output format
  # @param width [Integer, nil] a positive output-width bound
  # @param height [Integer, nil] a positive output-height bound
  # @param scale [Numeric, nil] a positive multiplier applied to both source
  #   dimensions; cannot be combined with another sizing mode
  # @param maximum_pixels [Integer, nil] a positive output pixel-count ceiling;
  #   cannot be combined with another sizing mode and never enlarges the image
  # @param allow_upscale [Boolean] whether dimension or scale modes may exceed
  #   the source dimensions; defaults to `true`
  # @param maximum_quality [Integer, nil] the maximum output quality from
  #   1 through 100 for lossy output, or `nil` for no explicit ceiling
  #
  # @return [Boolean] `true` when the output is written successfully
  #
  # @raise [ArgumentError] if sizing arguments, quality, or path types are invalid
  # @raise [Discourse::InvalidAccess] if a path is not absolute or safe
  # @raise [UnsupportedFormatError] if an input or output format is unsupported
  # @raise [InvalidImageError] if the input cannot be decoded
  # @raise [MetadataUnavailableError] if the input cannot be read
  # @raise [ProcessingFailedError] if the output cannot be produced
  # @raise [TimeoutError] if the internal deadline is exceeded
  #
  # @note The output is created or replaced atomically. The input is unchanged
  #   unless input and output identify the same path.
  def self.resize(
    input:,
    output:,
    width: nil,
    height: nil,
    scale: nil,
    maximum_pixels: nil,
    allow_upscale: true,
    maximum_quality: nil
  )
    validate_resize_options(
      width: width,
      height: height,
      scale: scale,
      maximum_pixels: maximum_pixels,
      allow_upscale: allow_upscale,
      maximum_quality: maximum_quality,
    )
    transform(
      input: input,
      output: output,
      timeout: TRANSFORM_TIMEOUT_SECONDS,
      maximum_quality: maximum_quality,
    ) do |input_path, output_path, input_type, output_type|
      dimensions =
        resize_dimensions(
          input_path,
          width: width,
          height: height,
          scale: scale,
          maximum_pixels: maximum_pixels,
          allow_upscale: allow_upscale,
        )
      command = transform_command(input_path, input_type)
      command.push("-resize", dimensions) if dimensions
      command.concat(profile_arguments)
      command << encoder_path(output_path, output_type)
      command
    end
  end

  # Crops an image to exact dimensions.
  #
  # The image is scaled proportionally to cover the requested dimensions and
  # overflow is removed according to `position`. Animated images use their
  # first frame. The stored display orientation is applied before cropping.
  # Supported inputs are AVIF, GIF, ICO, JPEG, PNG, SVG, and WebP. Supported
  # outputs are the same raster formats, excluding SVG.
  #
  # @param input [String, Pathname] an absolute local input path
  # @param output [String, Pathname] an absolute local output path; its
  #   extension determines the output format
  # @param width [Integer] the required positive output width in pixels
  # @param height [Integer] the required positive output height in pixels
  # @param position [Symbol] where retained image content is positioned; one
  #   of `:center` or `:top`; defaults to `:center`
  # @param maximum_quality [Integer, nil] the maximum output quality from
  #   1 through 100 for lossy output, or `nil` for no explicit ceiling
  #
  # @return [Boolean] `true` when the output is written successfully
  #
  # @raise [ArgumentError] if dimensions, position, quality, or path types are invalid
  # @raise [Discourse::InvalidAccess] if a path is not absolute or safe
  # @raise [UnsupportedFormatError] if an input or output format is unsupported
  # @raise [InvalidImageError] if the input cannot be decoded
  # @raise [MetadataUnavailableError] if the input cannot be read
  # @raise [ProcessingFailedError] if the output cannot be produced
  # @raise [TimeoutError] if the internal deadline is exceeded
  #
  # @note The output is created or replaced atomically. The input is unchanged
  #   unless input and output identify the same path.
  def self.crop(input:, output:, width:, height:, position: :center, maximum_quality: nil)
    validate_positive_integer(width, name: :width)
    validate_positive_integer(height, name: :height)
    raise ArgumentError, "position must be :center or :top" if !%i[center top].include?(position)
    validate_quality(maximum_quality)

    transform(
      input: input,
      output: output,
      timeout: TRANSFORM_TIMEOUT_SECONDS,
      maximum_quality: maximum_quality,
    ) do |input_path, output_path, input_type, output_type|
      geometry = "#{width}x#{height}"
      command = transform_command(input_path, input_type)
      command.concat(["-gravity", position == :top ? "north" : "center"])
      command.concat([metadata_resize_option, "#{geometry}^"])
      command.concat(["-extent", geometry, "-interpolate", "catrom", "-unsharp", "2x0.5+0.7+0"])
      command.concat(profile_arguments)
      command << encoder_path(output_path, output_type)
      command
    end
  end

  # Converts an image to another encoded format.
  #
  # The output format is determined from the output filename extension.
  # Dimensions, aspect ratio, and displayed orientation are preserved. ICO
  # inputs use their final embedded image. Supported inputs are AVIF, GIF, HEIC,
  # HEIF, ICO, JPEG, PNG, SVG, and WebP.
  # Supported outputs are AVIF, GIF, ICO, JPEG, PNG, and WebP.
  #
  # @param input [String, Pathname] an absolute local input path
  # @param output [String, Pathname] an absolute local output path; its
  #   extension determines the required output format
  # @param maximum_quality [Integer, nil] the maximum output quality from
  #   1 through 100 for lossy output, or `nil` for no explicit ceiling
  # @param timeout [Numeric] maximum processing time; defaults to 20 seconds
  #
  # @return [Boolean] `true` when the output is written successfully
  #
  # @raise [ArgumentError] if quality, timeout, or path types are invalid
  # @raise [Discourse::InvalidAccess] if a path is not absolute or safe
  # @raise [UnsupportedFormatError] if an input or output format is unsupported
  # @raise [InvalidImageError] if the input cannot be decoded
  # @raise [MetadataUnavailableError] if the input cannot be read
  # @raise [ProcessingFailedError] if the output cannot be produced
  # @raise [TimeoutError] if the deadline is exceeded
  #
  # @note The output is created or replaced atomically. The input is unchanged
  #   unless input and output identify the same path.
  def self.convert(input:, output:, maximum_quality: nil, timeout: 20)
    validate_quality(maximum_quality)
    validate_timeout(timeout)

    transform(
      input: input,
      output: output,
      timeout: timeout,
      maximum_quality: maximum_quality,
      supported_input_types: CONVERT_TYPES,
      optimize_output: false,
    ) do |input_path, output_path, input_type, output_type|
      command = ["magick"]
      command << decoder_path(input_path, input_type, frame: input_type == :ico ? :last : nil)
      command << "-auto-orient"
      if output_type == :jpeg
        command.concat(%w[-background white -flatten -interlace none])
      elsif input_type == :svg && output_type == :png
        command.concat(%w[-background none -depth 8 -define png:compression-level=9])
      end
      command << encoder_path(output_path, output_type)
      command
    end
  end

  # Re-encodes an image in place when its encoding quality exceeds a maximum.
  #
  # The encoded format, dimensions, aspect ratio, framing, and displayed
  # orientation are preserved. When source quality cannot be determined, the image is re-encoded
  # conservatively.
  #
  # @param path [String, Pathname] an absolute local path to the image that
  #   will be modified
  # @param maximum_quality [Integer] the maximum encoding quality from
  #   1 through 100
  # @param timeout [Numeric] maximum processing time; defaults to 20 seconds
  #
  # @return [Boolean] `true` when the image is re-encoded, or `false` when it
  #   is already at or below the maximum
  #
  # @raise [ArgumentError] if quality, timeout, or the path type is invalid
  # @raise [Discourse::InvalidAccess] if the path is not absolute or safe
  # @raise [UnsupportedFormatError] if the format cannot be recompressed
  # @raise [InvalidImageError] if the image cannot be decoded
  # @raise [MetadataUnavailableError] if the image cannot be read
  # @raise [ProcessingFailedError] if the image cannot be replaced
  # @raise [TimeoutError] if the deadline is exceeded
  def self.recompress!(path, maximum_quality:, timeout: 20)
    validate_quality(maximum_quality, allow_nil: false)
    validate_timeout(timeout)
    return false if maximum_quality == 100

    input_path = validated_input_path(path)
    image_type = type(input_path)
    raise UnsupportedFormatError if image_type != :jpeg

    quality = estimated_quality(input_path, image_type: image_type)
    return false if quality && quality <= maximum_quality

    with_atomic_output(input_path) do |output_path|
      execute_command(
        "magick",
        decoder_path(input_path, image_type),
        "-quality",
        maximum_quality.to_s,
        encoder_path(output_path, image_type),
        timeout: timeout,
      )
    end
    true
  end

  # Optimizes an image file in place.
  #
  # The encoded format, dimensions, aspect ratio, framing, and displayed
  # orientation are preserved. If orientation metadata is stripped, its
  # transformation is first applied to the pixels. JPEG and PNG are supported.
  #
  # @param path [String, Pathname] an absolute local path to the image that
  #   will be modified
  # @param allow_lossy [Boolean] whether optimization may discard image data;
  #   defaults to `false`
  #
  # @return [Boolean] `true` when orientation is applied or the file is
  #   replaced by a smaller optimized result; otherwise `false`
  #
  # @raise [ArgumentError] if `allow_lossy` or the path type is invalid
  # @raise [Discourse::InvalidAccess] if the path is not absolute or safe
  # @raise [UnsupportedFormatError] if the format cannot be optimized
  # @raise [InvalidImageError] if the image cannot be decoded
  # @raise [MetadataUnavailableError] if the image cannot be read
  # @raise [ProcessingFailedError] if optimization fails
  # @raise [TimeoutError] if the internal processing deadline is exceeded
  def self.optimize!(path, allow_lossy: false)
    raise ArgumentError, "allow_lossy must be true or false" if ![true, false].include?(allow_lossy)

    input_path = validated_input_path(path)
    image_type = type(input_path)
    raise UnsupportedFormatError if !OPTIMIZABLE_TYPES.include?(image_type)

    orientation_changed =
      SiteSetting.strip_image_metadata && apply_orientation_before_metadata_strip(input_path)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    optimized = image_optimizer(allow_lossy: allow_lossy).optimize_image!(input_path)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
    raise TimeoutError if !optimized && elapsed >= OPTIMIZE_TIMEOUT_SECONDS

    orientation_changed || !!optimized
  rescue Error, ArgumentError
    raise
  rescue ImageOptim::Error, ImageOptim::ConfigurationError => error
    raise ProcessingFailedError, error.message
  rescue IOError, SystemCallError => error
    raise ProcessingFailedError, error.message
  end

  def self.with_metadata_errors(source, timeout:)
    validate_timeout(timeout)
    normalized_source = source.is_a?(Pathname) ? source.to_s : source
    yield normalized_source
  rescue UnsupportedFormatError, InvalidImageError, MetadataUnavailableError, TimeoutError
    raise
  rescue FastImage::UnknownImageType
    raise UnsupportedFormatError
  rescue FastImage::SizeNotFound, FastImage::CannotParseImage, ProcessingFailedError
    raise InvalidImageError
  rescue FastImage::BadImageURI,
         FastImage::ImageFetchFailure,
         IOError,
         SystemCallError,
         URI::Error => error
    raise MetadataUnavailableError, error.message
  rescue Timeout::Error, Net::OpenTimeout, Net::ReadTimeout => error
    raise TimeoutError, error.message
  ensure
    if source.respond_to?(:rewind) && (!source.respond_to?(:closed?) || !source.closed?)
      source.rewind
    end
  end
  private_class_method :with_metadata_errors

  def self.svg_dimensions(source, path, timeout:)
    dimensions = FastImage.size(source, timeout: timeout, raise_on_failure: true)
    return dimensions if dimensions&.length == 2 && dimensions.all? { |value| value.to_i.positive? }

    svg_size(path, timeout: timeout)
  rescue FastImage::SizeNotFound, FastImage::CannotParseImage
    svg_size(path, timeout: timeout)
  end
  private_class_method :svg_dimensions

  def self.svg_size(path, timeout:)
    execute_command(
      "identify",
      "-ping",
      "-format",
      "%w %h",
      "MSVG:#{path}",
      timeout: timeout,
    ).split.map(&:to_i)
  end
  private_class_method :svg_size

  def self.local_source_path(source)
    value = source.is_a?(Pathname) ? source.to_s : source
    return value if value.is_a?(String) && !value.match?(/\A(?:https?|data):/i)

    value.path.to_s if value.respond_to?(:path) && value.path
  end
  private_class_method :local_source_path

  def self.frame_count(path, image_type:, timeout:)
    input_path = decoder_path(path, image_type)
    execute_command("identify", "-ping", "-format", "%n\n", input_path, timeout: timeout).to_i
  end
  private_class_method :frame_count

  def self.transform(
    input:,
    output:,
    timeout:,
    maximum_quality:,
    supported_input_types: TRANSFORM_TYPES,
    optimize_output: true
  )
    input_path = validated_input_path(input)
    output_path = validated_output_path(output)
    input_type = type(input_path)
    output_type = output_type(output_path)
    raise UnsupportedFormatError if !supported_input_types.include?(input_type)

    size(input_path)
    with_atomic_output(output_path) do |command_output_path|
      command = yield(input_path, command_output_path, input_type, output_type)
      append_quality(command, input_path, input_type, output_type, maximum_quality)
      execute_command(*command, timeout: timeout)
      optimize_transformed_output(command_output_path, output_type) if optimize_output
    end
    true
  end
  private_class_method :transform

  def self.transform_command(input_path, input_type)
    [
      "nice",
      "-n",
      "10",
      "convert",
      decoder_path(input_path, input_type, frame: :first),
      "-auto-orient",
      "-gravity",
      "center",
      "-background",
      "transparent",
      "-interlace",
      "none",
    ]
  end
  private_class_method :transform_command

  def self.resize_dimensions(input_path, width:, height:, scale:, maximum_pixels:, allow_upscale:)
    return resize_scale(scale, allow_upscale: allow_upscale) if scale
    if maximum_pixels
      source_width, source_height = size(input_path)
      return if source_width * source_height <= maximum_pixels

      return "#{maximum_pixels}@"
    end

    suffix = allow_upscale ? "" : ">"
    "#{width}x#{height}#{suffix}"
  end
  private_class_method :resize_dimensions

  def self.resize_scale(scale, allow_upscale:)
    effective_scale = allow_upscale ? scale : [scale, 1].min
    "#{effective_scale * 100}%"
  end
  private_class_method :resize_scale

  def self.validate_resize_options(
    width:,
    height:,
    scale:,
    maximum_pixels:,
    allow_upscale:,
    maximum_quality:
  )
    dimension_mode = width || height
    modes = [!!dimension_mode, !scale.nil?, !maximum_pixels.nil?]
    raise ArgumentError, "exactly one sizing mode is required" if modes.count(true) != 1

    validate_positive_integer(width, name: :width) if width
    validate_positive_integer(height, name: :height) if height
    raise ArgumentError, "scale must be positive" if scale && (!scale.is_a?(Numeric) || scale <= 0)
    validate_positive_integer(maximum_pixels, name: :maximum_pixels) if maximum_pixels
    if ![true, false].include?(allow_upscale)
      raise ArgumentError, "allow_upscale must be true or false"
    end
    validate_quality(maximum_quality)
  end
  private_class_method :validate_resize_options

  def self.validate_positive_integer(value, name:)
    raise ArgumentError, "#{name} must be a positive Integer" if !value.is_a?(Integer) || value <= 0
  end
  private_class_method :validate_positive_integer

  def self.validate_quality(value, allow_nil: true)
    return if value.nil? && allow_nil
    if !value.is_a?(Integer) || !value.between?(1, 100)
      raise ArgumentError, "maximum_quality must be between 1 and 100"
    end
  end
  private_class_method :validate_quality

  def self.validate_timeout(value)
    raise ArgumentError, "timeout must be positive" if !value.is_a?(Numeric) || value <= 0
  end
  private_class_method :validate_timeout

  def self.validated_input_path(value)
    path = validated_path(value)
    if !File.file?(path) || !File.readable?(path)
      raise MetadataUnavailableError, "image does not exist"
    end

    path
  end
  private_class_method :validated_input_path

  def self.validated_output_path(value)
    path = validated_path(value)
    parent = File.dirname(path)
    raise MetadataUnavailableError, "output directory does not exist" if !Dir.exist?(parent)

    path
  end
  private_class_method :validated_output_path

  def self.validated_path(value)
    path = value.is_a?(Pathname) ? value.to_s : value
    raise ArgumentError, "path must be a String or Pathname" if !path.is_a?(String)
    if path != File.expand_path(path) || !SAFE_PATH_PATTERN.match?(path)
      raise Discourse::InvalidAccess
    end

    path
  end
  private_class_method :validated_path

  def self.output_type(path)
    extension = File.extname(path).delete_prefix(".").downcase
    extension = "jpeg" if extension == "jpg"
    image_type = extension.to_sym
    raise UnsupportedFormatError if !TRANSFORM_TYPES.include?(image_type) || image_type == :svg

    image_type
  end
  private_class_method :output_type

  def self.decoder_path(path, image_type, frame: nil)
    value =
      if %i[heic heif].include?(image_type)
        path
      elsif image_type == :svg
        "RSVG:#{path}"
      else
        "#{image_type}:#{path}"
      end
    return value if frame.nil?

    frame_index = frame == :last ? -1 : 0
    "#{value}[#{frame_index}]"
  end
  private_class_method :decoder_path

  def self.encoder_path(path, image_type)
    "#{image_type}:#{path}"
  end
  private_class_method :encoder_path

  def self.metadata_resize_option
    SiteSetting.strip_image_metadata ? "-thumbnail" : "-resize"
  end
  private_class_method :metadata_resize_option

  def self.profile_arguments
    ["-profile", Rails.root.join("vendor/data/RT_sRGB.icm").to_s]
  end
  private_class_method :profile_arguments

  def self.append_quality(command, input_path, input_type, output_type, maximum_quality)
    return if maximum_quality.nil? || !LOSSY_TYPES.include?(output_type)

    source_quality =
      if input_type == output_type && LOSSY_TYPES.include?(input_type)
        estimated_quality(input_path, image_type: input_type)
      end
    if source_quality.nil? || source_quality > maximum_quality
      command.insert(command.length - 1, "-quality", maximum_quality.to_s)
    end
  end
  private_class_method :append_quality

  def self.estimated_quality(path, image_type:)
    input_path = decoder_path(path, image_type)
    quality = execute_command("identify", "-ping", "-format", "%Q", input_path, timeout: 5).to_i
    quality if quality.positive?
  rescue Error
    nil
  end
  private_class_method :estimated_quality

  def self.optimize_transformed_output(path, output_type)
    return if !OPTIMIZABLE_TYPES.include?(output_type)

    allow_lossy = output_type == :png && File.size(path) < MAX_PNGQUANT_SIZE_BYTES
    optimize!(path, allow_lossy: allow_lossy)
  end
  private_class_method :optimize_transformed_output

  def self.apply_orientation_before_metadata_strip(path)
    return false if orientation(path) == :normal

    image_type = type(path)
    with_atomic_output(path) do |output_path|
      execute_command(
        "magick",
        decoder_path(path, image_type),
        "-auto-orient",
        encoder_path(output_path, image_type),
        timeout: 5,
      )
    end
    true
  end
  private_class_method :apply_orientation_before_metadata_strip

  def self.image_optimizer(allow_lossy:)
    @image_optimizers ||= {}
    @image_optimizers[[allow_lossy, SiteSetting.strip_image_metadata]] ||= ImageOptim.new(
      timeout: OPTIMIZE_TIMEOUT_SECONDS,
      skip_missing_workers: true,
      oxipng: {
        level: 3,
        strip: SiteSetting.strip_image_metadata,
      },
      optipng: false,
      advpng: false,
      pngcrush: false,
      pngout: false,
      pngquant: allow_lossy ? { allow_lossy: true } : false,
      jpegoptim: {
        strip: SiteSetting.strip_image_metadata ? "all" : "none",
      },
      jpegtran: false,
      jpegrecompress: false,
      gifsicle: false,
      svgo: false,
    )
  end
  private_class_method :image_optimizer

  def self.with_atomic_output(output_path)
    extension = File.extname(output_path)
    Tempfile.create(
      ["discourse-image", extension],
      File.dirname(output_path),
      binmode: true,
    ) do |temporary_file|
      temporary_path = temporary_file.path
      temporary_file.close
      FileUtils.rm_f(temporary_path)
      yield temporary_path
      FileUtils.mv(temporary_path, output_path)
    ensure
      FileUtils.rm_f(temporary_path) if temporary_path
    end
  rescue IOError, SystemCallError => error
    raise ProcessingFailedError, error.message
  end
  private_class_method :with_atomic_output

  def self.execute_command(*command, timeout:)
    Discourse::Utils.execute_command(*command, timeout: timeout)
  rescue Discourse::Utils::CommandError => error
    if error.status&.exitstatus == 124
      raise TimeoutError, error.message
    else
      raise ProcessingFailedError, error.message
    end
  rescue SystemCallError => error
    raise ProcessingFailedError, error.message
  end
  private_class_method :execute_command
end
