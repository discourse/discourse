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

pairs_path = File.expand_path(ARGV.fetch(0))
pairs = JSON.parse(File.read(pairs_path))
raise "Expected exactly six ICO pairs" unless pairs.size == 6
output_root = File.expand_path(ARGV.fetch(1))
raise "Use a fresh ICO companion output directory" if File.exist?(output_root)
FileUtils.mkdir_p(output_root)
results = {
  source: source_manifest,
  harness_sha256: Digest::SHA256.file(__FILE__).hexdigest,
  pairs_sha256: Digest::SHA256.file(pairs_path).hexdigest,
  boundary: "Actual FileHelper optimizer on ICO outputs; complete file hashes and subprocess events only. No decoding, pixel comparison, or complete caller claim.",
  resolves: "The main companion could not inspect ICO through Vips.new_from_file before optimization; its original error records are retained.",
  ruby: RUBY_DESCRIPTION,
  cases: [],
}
pairs.each_with_index do |pair, index|
  raise "Unexpected operation" unless %w[downsize resize].include?(pair.fetch("operation"))
  [false, true].each do |strip|
    SiteSetting.strip_image_metadata = strip
    record = { name: pair.fetch("name"), operation: pair.fetch("operation"), strip_metadata: strip, provenance: pair.fetch("provenance"), backends: {} }
    %w[imagemagick libvips].each do |backend|
      OptimizerCommandEvidence.events = []
      begin
        original = File.expand_path(pair.fetch(backend))
        raise "Expected ICO output" unless File.extname(original).downcase == ".ico"
        before_sha256 = Digest::SHA256.file(original).hexdigest
        raise "Input checksum mismatch" unless before_sha256 == pair.fetch("input_sha256").fetch(backend)
        output = File.join(output_root, "#{index}-#{backend}-strip-#{strip}.ico")
        FileUtils.cp(original, output)
        optimizer_result = FileHelper.optimize_image!(output)
        after_sha256 = Digest::SHA256.file(output).hexdigest
        raise "Optimizer changed ICO bytes" unless before_sha256 == after_sha256
        raise "Original input changed" unless Digest::SHA256.file(original).hexdigest == before_sha256
        raise "Unexpected ICO optimizer command" unless OptimizerCommandEvidence.events.empty?
        record[:backends][backend] = { original:, output:, bytes: File.size(output), before_sha256:, after_sha256:, unchanged: true, optimizer_result: optimizer_result&.to_s, allow_pngquant: false, commands: OptimizerCommandEvidence.events }
      rescue StandardError => error
        record[:backends][backend] = { error: "#{error.class}: #{error.message}", commands: OptimizerCommandEvidence.events }
      end
    end
    results[:cases] << record
    File.write(File.join(output_root, "results.json"), JSON.pretty_generate(results))
  end
end
puts JSON.pretty_generate(results)
exit(results.fetch(:cases).all? { |record| record.fetch(:backends).values.all? { |backend| backend[:unchanged] } } ? 0 : 1)
