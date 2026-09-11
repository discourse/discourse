require "json"
require "pathname"
require "tmpdir"
require "fileutils"
require "digest"

unless defined?(Rails.application)
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
end

source_head = "6eda6188fca6bfa384406e9934e4547201cb08f2"
worker_sha256 = Digest::SHA256.file(Rails.root.join("script/discourse_vips_worker")).hexdigest
raise "Worker does not match #{source_head}" unless worker_sha256 == "2c2ff7fc5a7ead8358f073b71d2d5e5e299b7ff53585f4517b7b896e7e512df8"

memory_counter = "/sys/fs/cgroup/memory.current"
raise "Run in a dedicated Linux cgroup v2 container" unless File.readable?(memory_counter)

input_directory = Rails.root.join("spec/fixtures/images")
output_directory = File.expand_path(ENV.fetch("BENCHMARK_OUTPUT", "heif-benchmark-output"))
FileUtils.mkdir_p(output_directory)
files = %w[
  heif-color-grid-12bit.heic
  heif-color-grid-8bit.heic
  heif-color-grid-alpha-12bit.heic
  heif-color-grid-alpha-8bit.heic
  heif-color-grid-mirrored.heic
  heif-color-grid-rotated.heic
  should_be_jpeg.heic
  heif-truncated-payload.heic
]
iterations = 101
memory_iterations = 101
results = []

def process_tree_pids(pid)
  pids = [pid]
  pids.each do |current|
    pids.concat(File.read("/proc/#{current}/task/#{current}/children").split.map(&:to_i))
  rescue Errno::ENOENT, Errno::ESRCH
  end
  pids.sort
end


%i[imagemagick libvips].each do |backend|
  output, child_output = IO.pipe
  child_control, control = IO.pipe
  pid = fork do
    output.close
    control.close
    child_output.sync = true
    DiscourseVips.version if backend == :libvips

    files.each do |filename|
      path = File.join(input_directory, filename)
      output_path = File.join(output_directory, "#{filename}-#{backend}.jpg")
      FileUtils.rm_f(output_path)
      operation = -> do
        if backend == :libvips
          DiscourseVips.heif_to_jpeg(input_path: path, output_path:, timeout: 20)
        else
          ImageMagick.magick(path, "-auto-orient", "-background", "white", "-interlace", "none", "-flatten", output_path, operation: :upload_format_conversion, read: [path], write: [output_directory], timeout: 20)
        end
        { status: "ok" }
      rescue StandardError => error
        { status: "error", error_class: error.class.name }
      end

      value = operation.call
      expected_status = filename == "heif-truncated-payload.heic" ? "error" : "ok"
      raise "Unexpected conversion outcome: #{filename}: #{value}" unless value.fetch(:status) == expected_status
      timings = Array.new(iterations) do
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        raise "Conversion outcome changed" unless operation.call == value
        (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
      end
      child_output.puts(JSON.generate(backend:, filename:, value:, median_ms: timings.sort[iterations / 2], timings_ms: timings))
      memory_iterations.times do
        raise "Memory phase was not acknowledged" unless child_control.gets == "measure\n"
        raise "Conversion outcome changed" unless operation.call == value
        child_output.puts("done")
      end
      raise "Next sample was not acknowledged" unless child_control.gets == "next\n"
    end
    DiscourseVips.before_fork if backend == :libvips
    exit! 0
  end
  child_output.close
  child_control.close
  control.sync = true

  files.each do
    row = JSON.parse(output.gets || raise("Benchmark child exited unexpectedly"))
    memory = Array.new(memory_iterations) do
      expected_processes = backend == :libvips ? 2 : 1
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      until process_tree_pids(pid).length == expected_processes
        raise "Backend did not become idle" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        sleep 0.001
      end
      peak = baseline = Integer(File.read(memory_counter))
      samples = 1
      control.puts("measure")
      until IO.select([output], nil, nil, 0.001)
        peak = [peak, Integer(File.read(memory_counter))].max
        samples += 1
      end
      raise "Memory phase failed" unless output.gets == "done\n"
      peak = [peak, Integer(File.read(memory_counter))].max
      { baseline_mib: baseline / 1048576.0, peak_mib: peak / 1048576.0,
        incremental_peak_mib: [peak - baseline, 0].max / 1048576.0, samples: }
    end
    deltas = memory.map { |sample| sample.fetch(:incremental_peak_mib) }.sort
    results << row.merge(median_incremental_peak_mib: deltas[memory_iterations / 2], memory:)
    control.puts("next")
  end
  Process.wait(pid)
  raise "Benchmark child failed" unless $?.success?
  output.close
  control.close
end

puts JSON.pretty_generate(source_head:, worker_sha256:, iterations:, memory_iterations:, memory_poll_seconds: 0.001, memory_counter:, ruby: RUBY_DESCRIPTION, results:)
