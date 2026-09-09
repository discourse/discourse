require "bundler/setup"
require "active_support"
require "active_support/core_ext/object/blank"
require "pathname"
require "fileutils"
require "json"
require "digest"
require "landlock"
require "vips"

module Rails
  def self.root
    Pathname.new(__dir__)
  end

  def self.env
    "quality-benchmark"
  end
end

module SiteSetting
  def self.instrument_image_processing
    false
  end
end

module Discourse
  module Utils
    class CommandError < StandardError
      def initialize(message, **details)
        super(message)
      end
    end
  end
end

raise "Landlock is required" unless Landlock.supported?
manifest = JSON.parse(File.read(Rails.root.join("source-manifest.json")))
manifest.fetch("files").merge(manifest.fetch("dependency_hashes")).merge(manifest.fetch("reference_hashes")).each do |path, expected|
  raise "Frozen source changed: #{path}" unless Digest::SHA256.file(Rails.root.join(path)).hexdigest == expected
end
manifest.fetch("inputs").each do |sample|
  raise "Input changed: #{sample.fetch('path')}" unless Digest::SHA256.file(Rails.root.join(sample.fetch("path"))).hexdigest == sample.fetch("sha256")
end
$LOAD_PATH.unshift(Rails.root.join("lib").to_s)
require "discourse/safe_exec"
require "image_magick"
require "discourse_vips"
FileUtils.mkdir_p(Rails.root.join("tmp"))
Vips.cache_set_max(0)
Vips.concurrency_set(1)
require_relative "support"
case ENV.fetch("MODE")
when "prepare"
  load Rails.root.join("prepare.rb")
when "benchmark"
  load Rails.root.join("benchmark.rb")
when "matrix"
  load Rails.root.join("matrix.rb")
else
  raise "MODE must be prepare, benchmark, or matrix"
end
