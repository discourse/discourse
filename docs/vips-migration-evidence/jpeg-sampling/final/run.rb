require "bundler/setup"
require "active_support"
require "active_support/core_ext/object/blank"
require "pathname"
require "fileutils"
require "json"
require "digest"
require "landlock"
require "vips"
require "i18n"

module Rails
  def self.root
    Pathname.new(__dir__)
  end

  def self.env
    "benchmark"
  end
end

module SiteSetting
  class << self
    attr_accessor :strip_image_metadata
  end

  def self.instrument_image_processing
    false
  end
end

module Discourse
  class InvalidAccess < StandardError
  end

  module Utils
    class CommandError < StandardError
      def initialize(message, **details)
        super([message, details.inspect].join("\n"))
      end
    end
  end
end

I18n.enforce_available_locales = false
I18n.backend.store_translations(:en, upload: { png_to_jpg_conversion_failure_message: "JPEG conversion failed" })
raise "Production evidence requires Landlock" unless Landlock.supported?
$LOAD_PATH.unshift(File.join(__dir__, "lib"))
require "discourse/safe_exec"
require "image_magick"
require "discourse_vips"
require "geometry_commands"
require "conversion_command"
manifest = JSON.parse(File.read(Rails.root.join("source-manifest.json")))
manifest.fetch("files").merge(manifest.fetch("bundle_files")).each do |path, expected|
  raise "Snapshot checksum mismatch: #{path}" unless Digest::SHA256.file(Rails.root.join(path)).hexdigest == expected
end
Vips.cache_set_max(0)
Vips.concurrency_set(1)
FileUtils.mkdir_p(Rails.root.join("tmp"))
directory = Rails.root.join("outputs-final-selective")
FileUtils.mkdir_p(directory)
source_png = directory.join("source.png").to_s
coordinates = Vips::Image.xyz(96, 64)
image = (coordinates[0] * 255.0 / 95).bandjoin(coordinates[1] * 255.0 / 63).bandjoin(((coordinates[0] / 4).floor % 2) * 255).cast(:uchar).copy(interpretation: :srgb)
image.pngsave(source_png)
sources = { "png" => source_png }
{ "444" => "1x1,1x1,1x1", "420" => "2x2,1x1,1x1", "422" => "2x1,1x1,1x1", "440" => "1x2,1x1,1x1" }.each do |label, factors|
  path = directory.join("source-#{label}.jpg").to_s
  ImageMagick.magick("png:#{source_png}", "-sampling-factor", factors, "-quality", "89", "jpeg:#{path}", operation: :upload_format_conversion, read: [source_png], write: [directory.to_s], timeout: 20)
  sources[label] = path
end

def sampling_metadata(path)
  image = Vips::Image.new_from_file(path)
  profile = image.get_typeof("icc-profile-data") != 0 ? image.get("icc-profile-data") : nil
  {
    dimensions: [image.width, image.height],
    bytes: File.size(path),
    sha256: Digest::SHA256.file(path).hexdigest,
    icc_sha256: profile ? Digest::SHA256.hexdigest(profile) : nil,
    native_sampling: image.get_typeof("jpeg-chroma-subsample") != 0 ? image.get("jpeg-chroma-subsample") : nil,
    exact_sampling_and_quality: File.extname(path) == ".jpg" ? ImageMagick.identify("-format", "%[jpeg:sampling-factor]|%Q", path, operation: :upload_quality_probe, read: [path], timeout: 5) : nil,
  }
end

cases = []
sources.each do |label, source|
  source_format = label == "png" ? "png" : "jpeg"
  %w[resize crop downsize convert_to_jpeg auto_orient].each do |operation|
    next if label == "png" && operation == "auto_orient"
    qualities = if %w[downsize auto_orient].include?(operation)
      [nil]
    elsif operation == "convert_to_jpeg"
      label == "png" ? [nil, 89, 90] : [89, 90]
    else
      [nil, 89, 90]
    end
    modes = %w[resize crop].include?(operation) ? [false, true] : [false]
    qualities.product(modes).each do |requested_quality, strip|
      cases << { label:, source:, source_format:, operation:, requested_quality:, strip: }
    end
  end
end
results = { snapshot: manifest, ruby: RUBY_DESCRIPTION, libvips: Vips.version_string, boundary: "Transformation compatibility only; no optimizer, no timing claims; JPEG orientation uses identity orientation to isolate encoding policy", png_orientation: "Excluded: upload orientation gate admits JPEG; native auto_orient enforces JPEG", cases: [] }
converter = ConversionCommand.new
cases.each_with_index do |example, index|
  source = example.fetch(:source)
  source_format = example.fetch(:source_format)
  operation = example.fetch(:operation)
  requested = example.fetch(:requested_quality)
  quality = requested || (source_format == "jpeg" ? 89 : 92)
  SiteSetting.strip_image_metadata = example.fetch(:strip)
  entry = example.merge(source_metadata: sampling_metadata(source), native_quality: quality, backends: {})
  paths = {}
  %w[imagemagick libvips].each do |backend|
    output = directory.join("#{index}-#{backend}.jpg").to_s
    begin
      if backend == "imagemagick"
        if %w[resize crop downsize].include?(operation)
          dimensions = operation == "downsize" ? "50%" : "30x20"
          opts = { format: "jpeg" }
          opts[:quality] = requested if requested
          instructions = OptimizedImage.public_send("#{operation}_instructions", source, output, dimensions, opts)
          entry[:imagemagick_instructions] = instructions
          ImageMagick.magick(*instructions, operation: :"optimized_image_#{operation}", read: [source], write: [directory.to_s], nice: 10, timeout: 20)
        elsif operation == "convert_to_jpeg"
          converter.execute_convert("#{source_format}:#{source}", "jpeg:#{output}", requested ? { quality: requested } : {}, read: [source], write: [directory.to_s])
        else
          FileUtils.cp(source, output)
          ImageMagick.magick("jpeg:#{output}", "-auto-orient", "jpeg:#{output}", operation: :upload_auto_orient, read: [output], write: [output, directory.to_s], timeout: 5)
        end
      else
        arguments = { input_path: source, output_path: output, timeout: 20 }
        case operation
        when "resize", "crop"
          arguments.merge!(input_format: source_format, output_format: "jpeg", width: 30, height: 20, quality:, strip_metadata: example.fetch(:strip))
        when "downsize"
          arguments.merge!(input_format: source_format, output_format: "jpeg", geometry: "50%", quality:)
        when "convert_to_jpeg"
          arguments.merge!(input_format: source_format, quality:)
        when "auto_orient"
          arguments.merge!(source_quality: quality, timeout: 5)
        end
        DiscourseVips.public_send(operation, **arguments)
      end
      entry[:backends][backend] = sampling_metadata(output)
      paths[backend] = output
    rescue StandardError => error
      entry[:backends][backend] = { error: "#{error.class}: #{error.message}" }
    end
  end
  if paths.size == 2
    first = Vips::Image.jpegload(paths.fetch("imagemagick")).colourspace(:srgb)
    second = Vips::Image.jpegload(paths.fetch("libvips")).colourspace(:srgb)
    if [first.width, first.height] == [second.width, second.height]
      stats = (first - second).abs.stats
      entry[:visible_rgb_difference] = { mean: stats.getpoint(4, 0).first, max: stats.getpoint(1, 0).first }
    else
      entry[:visible_rgb_difference] = { error: "Dimensions differ" }
    end
  end
  results[:cases] << entry
  File.write(ENV.fetch("RESULT_PATH", Rails.root.join("final-selective.json").to_s), JSON.pretty_generate(results))
end
puts JSON.pretty_generate(results)
