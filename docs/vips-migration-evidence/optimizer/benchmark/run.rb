require "bundler/setup"
require "active_support"
require "active_support/core_ext/object/blank"
require "pathname"
require "fileutils"
require "digest"
require "json"
require "zlib"
require "landlock"
require "vips"
require "image_optim"

module Rails
  def self.root
    Pathname.new(__dir__)
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
  module Utils
    class CommandError < StandardError
      def initialize(message, **details)
        super([message, details.inspect].join("\n"))
      end
    end
  end
end

raise "This companion requires the real Linux Landlock sandbox" unless Landlock.supported?
$LOAD_PATH.unshift(File.join(__dir__, "lib"))
require "discourse/safe_exec"
require "image_magick"
require "file_helper_optimizer"
require "freedom_patches/image_optim_sandbox"

module OptimizerCommandEvidence
  class << self
    attr_accessor :events
  end

  def run(*args)
    result = super
    OptimizerCommandEvidence.events << { arguments: args, result: }
    result
  rescue StandardError => error
    OptimizerCommandEvidence.events << { arguments: args, error: "#{error.class}: #{error.message}" }
    raise
  end
end
ImageOptim::Cmd.singleton_class.prepend(OptimizerCommandEvidence)
Vips.cache_set_max(0)
Vips.concurrency_set(1)

source_manifest = JSON.parse(File.read(File.join(__dir__, "source-manifest.json")))
source_manifest.fetch("files").each do |path, details|
  next if %w[lib/file_helper.rb app/models/optimized_image.rb].include?(path)
  raise "Copied source checksum mismatch: #{path}" unless Digest::SHA256.file(File.join(__dir__, path)).hexdigest == details.fetch("sha256")
end
raise "Extracted optimizer checksum mismatch" unless Digest::SHA256.file(File.join(__dir__, "lib/file_helper_optimizer.rb")).hexdigest == source_manifest.fetch("extracted_optimizer_sha256")
source_manifest.fetch("gem_versions").each do |name, version|
  actual = Gem.loaded_specs.fetch(name).version.to_s
  raise "Gem version mismatch: #{name} #{actual} != #{version}" unless actual == version
end

def image_metadata(path)
  image = Vips::Image.new_from_file(path, access: :sequential)
  metadata = { bytes: File.size(path), sha256: Digest::SHA256.file(path).hexdigest, dimensions: [image.width, image.height], format: image.format, interpretation: image.interpretation, bands: image.bands }
  %w[icc-profile-data exif-data xmp-data iptc-data].each do |field|
    value = image.get_typeof(field) != 0 ? image.get(field) : nil
    metadata[field] = value ? { bytes: value.bytesize, sha256: Digest::SHA256.hexdigest(value) } : nil
  end
  File.open(path, "rb") do |file|
    if file.read(8) == "\x89PNG\r\n\x1a\n".b
      chunks = []
      while header = file.read(8)
        length, type = header.unpack("Na4")
        chunk = { type:, bytes: length }
        if %w[iCCP eXIf sRGB gAMA tEXt zTXt iTXt].include?(type)
          raise "Metadata chunk exceeds probe bound" if length > 8_388_608
          contents = file.read(length)
          case type
          when "iCCP"
            profile = Zlib::Inflate.inflate(contents.split("\0", 2).last.byteslice(1..))
            chunk[:icc_sha256] = Digest::SHA256.hexdigest(profile)
          when "eXIf"
            chunk[:exif_sha256] = Digest::SHA256.hexdigest(contents)
          when "gAMA"
            chunk[:gamma] = contents.unpack1("N") / 100_000.0
          when "sRGB"
            chunk[:intent] = contents.getbyte(0)
          else
            chunk[:key] = contents.split("\0", 2).first
          end
        else
          file.seek(length, IO::SEEK_CUR)
        end
        file.seek(4, IO::SEEK_CUR)
        chunks << chunk
        break if type == "IEND"
      end
      metadata[:png_chunks] = chunks
    end
  end
  metadata
end

def visible_image(path)
  image = Vips::Image.new_from_file(path, access: :sequential)
  raise "Image exceeds 128 million pixels" if image.width * image.height > 128_000_000
  if image.get_typeof("icc-profile-data") != 0
    image = image.icc_transform("srgb", embedded: true, depth: 8)
  else
    metadata = image_metadata(path)
    gamma = metadata.fetch(:png_chunks, []).find { |chunk| chunk[:type] == "gAMA" }&.fetch(:gamma)
    raise "Nonstandard unprofiled gamma requires separate normalization: #{gamma}" if gamma && (gamma - 0.45455).abs > 0.0001
    image = image.colourspace(:srgb).cast(:uchar)
  end
  image = image.flatten(background: [255, 255, 255]) if image.has_alpha?
  image
end

def visible_difference(first_path:, second_path:)
  first = visible_image(first_path)
  second = visible_image(second_path)
  raise "Output dimensions differ" unless [first.width, first.height] == [second.width, second.height]
  statistics = (first - second).abs.stats
  { mean_absolute_rgb: statistics.getpoint(4, 0).first, maximum_absolute_rgb: statistics.getpoint(1, 0).first }
rescue StandardError => error
  { error: "#{error.class}: #{error.message}" }
end

pairs_path = File.expand_path(ARGV.fetch(0))
pairs = JSON.parse(File.read(pairs_path))
output_root = File.expand_path(ARGV[1] || File.join(__dir__, "outputs"))
FileUtils.mkdir_p(output_root)
results = { source: source_manifest, ruby: RUBY_DESCRIPTION, libvips: Vips.version_string, boundary: "Exact FileHelper optimizer stage only; excludes Rails upload admission, transformation, temporary-file adoption, persistence and timing benchmarks", normalization: "Embedded ICC to sRGB; untagged assumed sRGB except unsupported gamma reported; white alpha flatten; native reductions", cases: [] }
threshold = Integer(source_manifest.fetch("files").fetch("app/models/optimized_image.rb").fetch("threshold_source").split("=").last.delete("_"))
pairs.each_with_index do |pair, index|
  raise "Unknown operation" unless %w[resize crop downsize jpeg ico heif orientation].include?(pair.fetch("operation"))
  [false, true].each do |strip|
    SiteSetting.strip_image_metadata = strip
    record = { name: pair.fetch("name"), operation: pair.fetch("operation"), strip_metadata: strip, provenance: pair["provenance"], backends: {} }
    completed = {}
    %w[imagemagick libvips].each do |backend|
      OptimizerCommandEvidence.events = []
      begin
        original = File.expand_path(pair.fetch(backend), File.dirname(pairs_path))
        if pair["input_sha256"] && Digest::SHA256.file(original).hexdigest != pair.fetch("input_sha256").fetch(backend)
          raise "Input checksum changed: #{original}"
        end
        output = File.join(output_root, "#{index}-#{backend}-strip-#{strip}#{File.extname(original)}")
        raise "Output would overwrite original" if output == original
        FileUtils.cp(original, output)
        allow_pngquant = %w[resize crop downsize].include?(pair.fetch("operation")) && output.downcase.end_with?(".png") && File.size(output) < threshold
        before = image_metadata(output)
        optimizer_result = FileHelper.optimize_image!(output, allow_pngquant:)
        record[:backends][backend] = { original:, output:, allow_pngquant:, optimizer_result: optimizer_result&.to_s, before:, after: image_metadata(output), source_visible_difference: visible_difference(first_path: original, second_path: output), commands: OptimizerCommandEvidence.events }
        completed[backend] = output
      rescue StandardError => error
        record[:backends][backend] = { error: "#{error.class}: #{error.message}", commands: OptimizerCommandEvidence.events }
      end
    end
    if completed.size == 2
      record[:post_optimizer_backend_difference] = visible_difference(first_path: completed.fetch("imagemagick"), second_path: completed.fetch("libvips"))
    end
    results[:cases] << record
    File.write(File.join(output_root, "results.json"), JSON.pretty_generate(results))
  end
end
puts JSON.pretty_generate(results)
