require "json"
require "pathname"
require "tmpdir"
require "fileutils"
require "digest"
require "active_support"
require "active_support/core_ext/object/blank"
require "landlock"
require "vips"

module Rails
  def self.root = Pathname.new(Dir.pwd)
  def self.env = "benchmark"
end
module SiteSetting
  def self.instrument_image_processing = false
end
module Discourse
  module Utils
    class CommandError < StandardError
      def initialize(message, **details) = super(message)
    end
  end
end
$LOAD_PATH.unshift(Rails.root.join("lib").to_s)
require "discourse/safe_exec"
require "image_magick"
require "discourse_vips"

memory_counter = "/sys/fs/cgroup/memory.current"
raise "Run in a dedicated Linux cgroup v2 container" unless File.readable?(memory_counter)

root = Pathname.new(ENV.fetch("BENCHMARK_OUTPUT"))
FileUtils.rm_rf(root)
FileUtils.mkdir_p(root.join("inputs"))
FileUtils.mkdir_p(root.join("outputs"))

def raster(path, width, height)
  x = Vips::Image.xyz(width, height)[0]
  y = Vips::Image.xyz(width, height)[1]
  blue = ((x + y) * 3) % 256
  x.linear(255.0 / [width - 1, 1].max, 0).bandjoin(y.linear(255.0 / [height - 1, 1].max, 0)).bandjoin(blue).cast(:uchar).pngsave(path)
end

raster(root.join("inputs/percentage.png").to_s, 101, 51)
raster(root.join("inputs/bounding.png").to_s, 51, 101)
raster(root.join("inputs/area.png").to_s, 244, 66)
FileUtils.cp(Rails.root.join("spec/fixtures/images/tiny.svg"), root.join("inputs/tiny.svg"))

cases = [
  { name: "raster-percentage", input: "percentage.png", input_format: "png", output_format: "png", geometry: "50%" },
  { name: "raster-bounding-box", input: "bounding.png", input_format: "png", output_format: "png", geometry: "100x100>" },
  { name: "raster-pixel-area", input: "area.png", input_format: "png", output_format: "png", geometry: "1000@" },
  { name: "svg-percentage", input: "tiny.svg", input_format: "svg", output_format: "png", geometry: "50%" },
]
iterations = 101
memory_iterations = 101
results = []

%i[imagemagick libvips].each do |backend|
  output, child_output = IO.pipe
  child_control, control = IO.pipe
  pid = fork do
    output.close
    control.close
    child_output.sync = true
    DiscourseVips.version if backend == :libvips
    cases.each do |sample|
      input = root.join("inputs", sample.fetch(:input)).to_s
      destination = root.join("outputs", "#{sample.fetch(:name)}-#{backend}.png").to_s
      operation = lambda do
        if backend == :libvips
          DiscourseVips.downsize(input_path: input, output_path: destination, input_format: sample.fetch(:input_format), output_format: "png", geometry: sample.fetch(:geometry), quality: nil, timeout: 20)
        else
          decoder = sample.fetch(:input_format) == "svg" ? "MSVG" : "png"
          ImageMagick.magick("#{decoder}:#{input}[0]", "-auto-orient", "-gravity", "center", "-background", "transparent", "-interlace", "none", "-resize", sample.fetch(:geometry), "-profile", Rails.root.join("vendor/data/RT_sRGB.icm").to_s, "png:#{destination}", operation: :optimized_image_downsize, read: [input], write: [File.dirname(destination)], nice: 10, timeout: 20)
        end
      end
      operation.call
      timings = Array.new(iterations) do
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        operation.call
        (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
      end
      image = Vips::Image.new_from_file(destination)
      child_output.puts(JSON.generate(backend:, sample:, output: File.basename(destination), dimensions: [image.width, image.height], bytes: File.size(destination), sha256: Digest::SHA256.file(destination).hexdigest, median_ms: timings.sort[iterations / 2], timings_ms: timings))
      memory_iterations.times do
        raise "memory phase not acknowledged" unless child_control.gets == "measure\n"
        operation.call
        child_output.puts("done")
      end
      raise "next sample not acknowledged" unless child_control.gets == "next\n"
    end
    DiscourseVips.before_fork if backend == :libvips
    exit! 0
  end
  child_output.close
  child_control.close
  control.sync = true
  cases.each do
    row = JSON.parse(output.gets || raise("benchmark child exited"))
    memory = Array.new(memory_iterations) do
      sleep 0.005
      peak = baseline = Integer(File.read(memory_counter))
      samples = 1
      control.puts("measure")
      until IO.select([output], nil, nil, 0.001)
        peak = [peak, Integer(File.read(memory_counter))].max
        samples += 1
      end
      raise "memory phase failed" unless output.gets == "done\n"
      peak = [peak, Integer(File.read(memory_counter))].max
      { baseline_mib: baseline / 1048576.0, peak_mib: peak / 1048576.0, incremental_peak_mib: [peak - baseline, 0].max / 1048576.0, samples: }
    end
    deltas = memory.map { |sample| sample.fetch(:incremental_peak_mib) }.sort
    results << row.merge("median_incremental_peak_mib" => deltas[memory_iterations / 2], "memory" => memory)
    control.puts("next")
  end
  Process.wait(pid)
  raise "benchmark child failed" unless $?.success?
  output.close
  control.close
end
puts JSON.pretty_generate(head: ENV.fetch("SOURCE_HEAD"), iterations:, memory_iterations:, memory_poll_seconds: 0.001, image: ENV.fetch("PRODUCTION_IMAGE"), digest: ENV.fetch("PRODUCTION_DIGEST"), ruby: RUBY_DESCRIPTION, libvips: Vips.version_string, results:)
