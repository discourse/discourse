# frozen_string_literal: true

require "fileutils"
require "pathname"
require "safe_image"
require "tempfile"

module DiscourseImage
  SAFE_PATH_PATTERN = %r{\A[\w\-\./]+\z}m
  SNIFF_BYTES = 4096
  SVG_PREFIX_PATTERN =
    /\A(?:<\?xml[^>]*>\s*)?(?:<!--.*?-->\s*)*(?:<!doctype\s+svg\b[^>]*(?:\[[\s\S]*?\]\s*)?>\s*)?(?:<!--.*?-->\s*)*<svg(?:\s|>)/m
  SUPPORTED_EXTENSIONS = %w[jpg jpeg png ico gif webp avif heic heif jxl svg].freeze
  ISO_BMFF_BRANDS = {
    "avif" => "avif",
    "avis" => "avif",
    "heic" => "heic",
    "heix" => "heic",
    "hevc" => "heic",
    "hevx" => "heic",
    "mif1" => "heif",
    "msf1" => "heif",
  }.freeze

  module_function

  def info(path, filename: nil, type: nil, **kwargs)
    with_safe_input_path(path, filename: filename, type: type) do |safe_path|
      normalize_info(SafeImage.info(safe_path, **kwargs))
    end
  end

  def size(path, filename: nil, type: nil, **kwargs)
    with_safe_input_path(path, filename: filename, type: type) do |safe_path|
      SafeImage.size(safe_path, **kwargs)
    end
  end

  def type(path, filename: nil, **kwargs)
    with_safe_input_path(path, filename: filename) do |safe_path|
      SafeImage.type(safe_path, **kwargs)
    end
  end

  def orientation(path, filename: nil, type: nil, **kwargs)
    with_safe_input_path(path, filename: filename, type: type) do |safe_path|
      SafeImage.orientation(safe_path, **kwargs)
    end
  end

  def animated?(path, filename: nil, type: nil, **kwargs)
    with_safe_input_path(path, filename: filename, type: type) do |safe_path|
      SafeImage.animated?(safe_path, **kwargs)
    end
  end

  def frame_count(path, filename: nil, type: nil, **kwargs)
    with_safe_input_path(path, filename: filename, type: type) do |safe_path|
      SafeImage.frame_count(safe_path, **kwargs)
    end
  end

  def dominant_color(path, filename: nil, type: nil, **kwargs)
    with_safe_input_path(path, filename: filename, type: type) do |safe_path|
      SafeImage.dominant_color(safe_path, **kwargs)
    end
  end

  def resize(from, to, width, height, filename: nil, type: nil, output_extension: nil, **kwargs)
    with_safe_input_path(from, filename: filename, type: type) do |safe_from|
      with_safe_output_path(
        to,
        extension: output_extension || output_extension_for(to, filename: filename, type: type),
        force_temp: same_path?(safe_from, to),
      ) do |safe_to|
        SafeImage.resize(input: safe_from, output: safe_to, width: width, height: height, **kwargs)
      end
    end
  end

  def crop(from, to, width, height, filename: nil, type: nil, output_extension: nil, **kwargs)
    with_safe_input_path(from, filename: filename, type: type) do |safe_from|
      with_safe_output_path(
        to,
        extension: output_extension || output_extension_for(to, filename: filename, type: type),
        force_temp: same_path?(safe_from, to),
      ) do |safe_to|
        SafeImage.crop(input: safe_from, output: safe_to, width: width, height: height, **kwargs)
      end
    end
  end

  def downsize(from, to, dimensions, filename: nil, type: nil, output_extension: nil, **kwargs)
    with_safe_input_path(from, filename: filename, type: type) do |safe_from|
      with_safe_output_path(
        to,
        extension: output_extension || output_extension_for(to, filename: filename, type: type),
        force_temp: same_path?(safe_from, to),
      ) do |safe_to|
        SafeImage.downsize(input: safe_from, output: safe_to, dimensions: dimensions, **kwargs)
      end
    end
  end

  def convert(from, to, format:, filename: nil, type: nil, **kwargs)
    with_safe_input_path(from, filename: filename, type: type) do |safe_from|
      with_safe_output_path(to, extension: format) do |safe_to|
        SafeImage.convert(input: safe_from, output: safe_to, format: format, **kwargs)
      end
    end
  end

  def convert_to_jpeg(from, to, filename: nil, type: nil, **kwargs)
    with_safe_input_path(from, filename: filename, type: type) do |safe_from|
      with_safe_output_path(to, extension: "jpg") do |safe_to|
        SafeImage.convert(input: safe_from, output: safe_to, format: "jpg", **kwargs)
      end
    end
  end

  def convert_favicon_to_png(from, to, filename: nil, type: nil, **kwargs)
    with_safe_input_path(from, filename: filename, type: type || :ico) do |safe_from|
      with_safe_output_path(to, extension: "png") do |safe_to|
        SafeImage.convert_favicon_to_png(input: safe_from, output: safe_to, **kwargs)
      end
    end
  end

  def fix_orientation(from, to = from, filename: nil, type: nil, **kwargs)
    with_safe_input_path(from, filename: filename, type: type) do |safe_from|
      with_safe_output_path(
        to,
        extension: output_extension_for(to, filename: filename, type: type),
        force_temp: same_path?(safe_from, to),
      ) { |safe_to| SafeImage.fix_orientation(input: safe_from, output: safe_to, **kwargs) }
    end
  end

  def optimize_image!(path, filename: nil, type: nil, **kwargs)
    with_safe_input_path(path, filename: filename, type: type) do |safe_path|
      with_safe_output_path(
        path,
        extension: safe_extension_for(path, filename: filename, type: type),
        force_temp: true,
      ) do |safe_output|
        SafeImage.optimize(input: safe_path, output: safe_output, **optimize_options(**kwargs))
      end
    end
  end

  def with_safe_input_path(path, filename: nil, type: nil)
    original_path = local_path(path)
    extension = safe_extension_for(original_path, filename: filename, type: type)

    if extension && extension_matches?(original_path, extension) && safe_path?(original_path)
      yield File.expand_path(original_path)
    else
      extension ||= normalized_extension(File.extname(original_path))
      extension ||= "bin"

      Tempfile.create(["safe-image-input", ".#{extension}"], binmode: true) do |tempfile|
        tempfile.close
        FileUtils.cp(original_path, tempfile.path)
        yield tempfile.path
      end
    end
  end

  def with_safe_output_path(path, extension: nil, force_temp: false)
    original_path = local_path(path)
    extension = normalized_extension(extension) || normalized_extension(File.extname(original_path))
    if extension.blank? || !SUPPORTED_EXTENSIONS.include?(extension)
      raise Discourse::InvalidAccess.new("Unsupported extension: #{extension}")
    end

    force_temp ||= safe_image_landlock? && File.exist?(original_path)

    if !force_temp && extension_matches?(original_path, extension) && safe_path?(original_path)
      yield File.expand_path(original_path)
    else
      Tempfile.create(["safe-image-output", ".#{extension}"], binmode: true) do |tempfile|
        temp_path = tempfile.path
        tempfile.close
        FileUtils.rm_f(temp_path)
        result = yield temp_path
        FileUtils.mv(temp_path, original_path)
        result
      ensure
        FileUtils.rm_f(temp_path) if temp_path
      end
    end
  end

  def output_extension_for(path, filename: nil, type: nil)
    normalized_extension(File.extname(path)) || extension_for_type(type) ||
      normalized_extension(File.extname(filename.to_s))
  end

  def safe_extension_for(path, filename: nil, type: nil)
    sniff_extension(path) || extension_for_type(type) ||
      normalized_extension(File.extname(filename.to_s)) || normalized_extension(File.extname(path))
  end

  def extension_for_type(type)
    return if type.blank?

    normalized_extension(type.to_s)
  end

  def normalized_extension(value)
    extension = value.to_s.delete_prefix(".").downcase
    return if extension.blank?

    extension = "jpg" if extension == "jpeg"
    extension if SUPPORTED_EXTENSIONS.include?(extension)
  end

  def extension_matches?(path, extension)
    normalized_extension(File.extname(path)) == normalized_extension(extension)
  end

  def same_path?(left, right)
    File.expand_path(local_path(left)) == File.expand_path(local_path(right))
  end

  def safe_image_landlock?
    SafeImage.config.landlock
  rescue SafeImage::Error
    false
  end

  def optimize_options(allow_lossy_png: false, **kwargs)
    kwargs[:mode] ||= allow_lossy_png ? :lossy : :lossless
    kwargs
  end

  def normalize_info(info)
    return info if !info.type.is_a?(String)

    SafeImage::Info.new(**info.to_h.merge(type: info.type.to_sym))
  end

  def safe_path?(path)
    expanded = File.expand_path(path)
    expanded == path.to_s && SAFE_PATH_PATTERN.match?(expanded) && !symlink_path?(expanded)
  end

  def symlink_path?(path)
    Pathname
      .new(path)
      .ascend
      .any? do |component|
        component_path = component.to_s
        File.exist?(component_path) && File.lstat(component_path).symlink?
      end
  rescue SystemCallError
    true
  end

  def local_path(value)
    if value.respond_to?(:path) && value.path
      value.path.to_s
    else
      value.to_s
    end
  end

  def sniff_extension(path)
    head = File.open(path, "rb") { |file| file.read(SNIFF_BYTES).to_s.b }

    return "jpg" if head.start_with?("\xFF\xD8\xFF".b)
    return "png" if head.start_with?("\x89PNG\r\n\x1A\n".b)
    return "gif" if head.start_with?("GIF8".b)
    return "webp" if head.bytesize >= 12 && head[0, 4] == "RIFF".b && head[8, 4] == "WEBP".b
    return "ico" if head.start_with?("\x00\x00\x01\x00".b)
    if head.start_with?("\xFF\x0A".b) || head.start_with?("\x00\x00\x00\x0CJXL \r\n\x87\n".b)
      return "jxl"
    end

    if head.bytesize >= 12 && head[4, 4] == "ftyp".b
      brands = head[8, 64].to_s.scan(/[A-Za-z0-9]{4}/)
      brands.each { |brand| return ISO_BMFF_BRANDS[brand] if ISO_BMFF_BRANDS.key?(brand) }
    end

    text =
      head.encode("UTF-8", invalid: :replace, undef: :replace).sub("\uFEFF", "").lstrip.downcase
    "svg" if SVG_PREFIX_PATTERN.match?(text)
  rescue SystemCallError
    nil
  end
end
