require "bundler/setup"
require "active_support"
require "active_support/core_ext/object/blank"
require "pathname"
require "fileutils"
require "digest"
require "json"
require "landlock"
require "vips"

module Rails
  def self.root
    Pathname.new(ENV.fetch("GEOMETRY_ROOT"))
  end

  def self.env
    "optimizer-threshold"
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
manifest = JSON.parse(File.read(Rails.root.join("manifest.json")))
raise "Expected final c63 source" unless manifest.fetch("source").fetch("base_commit") == "c63ee831d4d2e332c466f1a272793eec94d9c22d"
manifest.fetch("source").fetch("files").each do |path, digest|
  raise "Source checksum mismatch: #{path}" unless Digest::SHA256.file(Rails.root.join(path)).hexdigest == digest
end
$LOAD_PATH.unshift(Rails.root.join("lib").to_s)
require "discourse/safe_exec"
require "image_magick"
require "discourse_vips"
FileUtils.mkdir_p(Rails.root.join("tmp"))
Vips.cache_set_max(0)
Vips.concurrency_set(1)

output_root = Pathname.new(File.expand_path(ARGV.fetch(0)))
raise "Use a fresh threshold output directory" if output_root.exist?
FileUtils.mkdir_p(output_root.join("outputs"))
input_path = output_root.join("seeded-rgb.png").to_s
noise = Random.new(20260909).bytes(1024 * 768 * 3)
Vips::Image.new_from_memory(noise, 1024, 768, 3, :uchar).copy(interpretation: :srgb).pngsave(input_path)
report = {
  source: manifest.fetch("source"),
  manifest_sha256: Digest::SHA256.file(Rails.root.join("manifest.json")).hexdigest,
  harness_sha256: Digest::SHA256.file(__FILE__).hexdigest,
  purpose: "Supplemental real geometry outputs for the >=500000-byte pngquant exclusion branch; no timing or performance claim",
  ruby: RUBY_DESCRIPTION,
  libvips: Vips.version_string,
  landlock: Landlock.supported?,
  seed: 20260909,
  input: { path: "seeded-rgb.png", sha256: Digest::SHA256.file(input_path).hexdigest, dimensions: [1024, 768], bytes: File.size(input_path) },
  samples: [],
}

[%w[downsize false], %w[crop false], %w[crop true], %w[resize false], %w[resize true]].each do |operation, strip_text|
  strip = strip_text == "true"
  name = "threshold-seeded-rgb-#{operation}-strip-#{strip}"
  sample = { operation:, name:, strip_metadata: strip, outputs: {}, status: "ok" }
  %w[imagemagick libvips].each do |backend|
    output_path = output_root.join("outputs", "#{name}-#{backend}.png").to_s
    begin
      if backend == "imagemagick"
        instructions = ["png:#{input_path}[0]", "-auto-orient", "-gravity", operation == "crop" ? "north" : "center", "-background", "transparent"]
        if operation == "downsize"
          instructions.concat(["-interlace", "none", "-resize", "75%"])
        else
          instructions.concat([strip ? "-thumbnail" : "-resize", "768x576^"])
          instructions.concat(operation == "crop" ? ["-crop", "768x576+0+0"] : ["-extent", "768x576", "-interpolate", "catrom"])
          instructions.concat(["-unsharp", "2x0.5+0.7+0", "-interlace", "none"])
        end
        instructions.concat(["-profile", Rails.root.join("vendor/data/RT_sRGB.icm").to_s, "png:#{output_path}"])
        sample[:instructions] = instructions
        ImageMagick.magick(*instructions, operation: :"optimized_image_#{operation}", read: [input_path], write: [File.dirname(output_path)], timeout: 20, nice: 10)
      else
        arguments = { input_path:, output_path:, input_format: "png", output_format: "png", quality: nil, timeout: 20 }
        if operation == "downsize"
          DiscourseVips.downsize(**arguments, geometry: "75%")
        elsif operation == "crop"
          DiscourseVips.crop(**arguments, width: 768, height: 576, strip_metadata: strip)
        else
          DiscourseVips.resize(**arguments, width: 768, height: 576, strip_metadata: strip)
        end
      end
      image = Vips::Image.pngload(output_path)
      raise "Output dimensions differ" unless [image.width, image.height] == [768, 576]
      sample[:outputs][backend] = { path: Pathname.new(output_path).relative_path_from(output_root).to_s, sha256: Digest::SHA256.file(output_path).hexdigest, bytes: File.size(output_path), dimensions: [image.width, image.height] }
      raise "Output is below the 500000-byte threshold" if File.size(output_path) < 500_000
    rescue StandardError => error
      sample[:status] = "error"
      sample[:errors] ||= {}
      sample[:errors][backend] = "#{error.class}: #{error.message}"
    end
  end
  report[:samples] << sample
  File.write(output_root.join("threshold-results.json"), JSON.pretty_generate(report))
end
puts JSON.pretty_generate(report)
exit(report.fetch(:samples).all? { |sample| sample.fetch(:status) == "ok" } ? 0 : 1)
