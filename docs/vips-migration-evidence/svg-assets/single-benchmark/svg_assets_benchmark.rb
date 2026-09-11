require "json"
require "pathname"
require "tmpdir"
require "fileutils"

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

memory_counter = "/sys/fs/cgroup/memory.current"
raise "Run in a dedicated Linux cgroup v2 container" unless File.readable?(memory_counter)

input_directory = Dir.mktmpdir("svg-assets-benchmark")
at_exit { FileUtils.remove_entry(input_directory) }
output_directory = File.expand_path(ENV.fetch("BENCHMARK_OUTPUT", "svg-assets-benchmark-output"))
FileUtils.mkdir_p(output_directory)
inputs = {
  "fixed.svg" => "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"120\" height=\"80\"/>\n",
  "gradient-logo.svg" => "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"240\" height=\"100\">\n  <defs>\n    <linearGradient id=\"logo-gradient\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"1\">\n      <stop stop-color=\"#0088cc\"/>\n      <stop offset=\"1\" stop-color=\"#00c8a0\"/>\n    </linearGradient>\n  </defs>\n  <rect x=\"4\" y=\"8\" width=\"80\" height=\"80\" rx=\"18\" fill=\"url(#logo-gradient)\"/>\n  <circle cx=\"44\" cy=\"48\" r=\"20\" fill=\"white\"/>\n  <path d=\"M30 61v17l20-17\" fill=\"white\"/>\n  <text x=\"98\" y=\"60\" font-family=\"sans-serif\" font-size=\"30\" font-weight=\"700\" fill=\"#123456\">FORUM</text>\n</svg>\n",
  "image.svg" => "<svg width=\"100\" height=\"50\">\n  <style>\n    .black { fill: #FFFFFF; }\n  </style>\n  <text class=\"black\" x=\"25\" y=\"25\">Discourse</text>\n</svg>\n",
  "leading-whitespace-viewbox.svg" => "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"0\" height=\"0\" viewBox=\" \t\n0\t0\n120 90\n \"/>\n",
  "tiny.svg" => "<?xml version='1.0' encoding='UTF-8'?>\n<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">\n<svg\n  xmlns=\"http://www.w3.org/2000/svg\" xmlns:svg=\"http://www.w3.org/2000/svg\"\n  width=\"1.2in\" height=\"0.9in\"\n  viewBox=\"0 0 1200 900\"\n>\n  <line x1=\"20\" x2=\"1000\" y1=\"20\" y2=\"700\" stroke=\"#ff88ff\" stroke-width=\"25\"/>\n</svg>\n",
  "transparency.svg" => "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"12\" height=\"4\"><rect width=\"4\" height=\"4\" fill=\"red\"/><rect x=\"4\" width=\"4\" height=\"4\" fill=\"green\" fill-opacity=\"0.5\"/></svg>",
  "viewbox.svg" => "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 120 90\"/>\n",
  "zero-height.svg" => "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"80\" height=\"0\" viewBox=\"0 0 120 90\"/>\n",
  "zero-width.svg" => "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"0\" height=\"60\" viewBox=\"0 0 120 90\"/>\n",
  "zero_sized.svg" => "<?xml version='1.0' encoding='UTF-8'?>\n<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">\n<svg\n  xmlns=\"http://www.w3.org/2000/svg\" xmlns:svg=\"http://www.w3.org/2000/svg\"\n  width=\"0.0in\" height=\"0.0in\"\n  viewBox=\"0 0 120 90\"\n>\n  <line x1=\"20\" x2=\"1000\" y1=\"20\" y2=\"700\" stroke=\"#ff88ff\" stroke-width=\"25\"/>\n</svg>\n",
  "physical-units.svg" => "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"2in\" height=\"1in\"><rect width=\"100%\" height=\"100%\" fill=\"#0088cc\"/><circle cx=\"48\" cy=\"48\" r=\"24\" fill=\"white\"/></svg>",
  "css-dimensions.svg" => "<svg xmlns=\"http://www.w3.org/2000/svg\" style=\"width:120px;height:80px\"><rect width=\"120\" height=\"80\" fill=\"#0088cc\"/></svg>",
  "malformed.svg" => "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"120\" height=\"80\"><",
}
inputs.each { |filename, contents| File.write(File.join(input_directory, filename), contents) }
files = inputs.keys
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
      output_path = File.join(output_directory, "#{File.basename(filename, '.svg')}-#{backend}.png")
      FileUtils.rm_f(output_path)
      operation = -> do
        if backend == :libvips
          DiscourseVips.svg_to_png(input_path: path, output_path:, timeout: 10)
        else
          ImageMagick.magick("MSVG:#{path}", output_path, operation: :topic_og_asset_render, read: [path], write: [output_directory], timeout: 10)
        end
        { status: "ok" }
      rescue StandardError => error
        { status: "error", error_class: error.class.name }
      end

      value = operation.call
      timings = Array.new(iterations) do
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        operation.call
        (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
      end
      child_output.puts(JSON.generate(backend:, filename:, value:, median_ms: timings.sort[iterations / 2], timings_ms: timings))
      memory_iterations.times do
        raise "Memory phase was not acknowledged" unless child_control.gets == "measure\n"
        operation.call
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

puts JSON.pretty_generate(iterations:, memory_iterations:, memory_poll_seconds: 0.001, memory_counter:, ruby: RUBY_DESCRIPTION, results:)
