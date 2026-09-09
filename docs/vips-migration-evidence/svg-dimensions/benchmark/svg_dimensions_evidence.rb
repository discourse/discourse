require "json"
require "digest"
require "fileutils"

def measure_operation(operation)
  started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  outcome =
    begin
      { status: "ok", value: operation.call }
    rescue StandardError => error
      { status: "error", error_class: error.class.name, message: error.message.lines.first&.strip }
    end
  elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000
  { outcome:, elapsed_ms: }
end

def distribution(measurements)
  durations_ms = measurements.map { |measurement| measurement.fetch(:elapsed_ms) }
  sorted = durations_ms.sort
  {
    median_ms: sorted[sorted.length / 2],
    p95_ms: sorted[[(sorted.length * 0.95).ceil - 1, sorted.length - 1].min],
    min_ms: sorted.first,
    max_ms: sorted.last,
    values_ms: durations_ms,
  }
end

iterations = 31
cold_starts = 5
success_cases = {
  "fixed.svg" => [120, 80],
  "image.svg" => [100, 50],
  "tiny.svg" => [115, 86],
  "massive.svg" => [11_520, 11_615],
  "viewbox.svg" => [120, 90],
  "zero_sized.svg" => [120, 90],
  "leading-whitespace-viewbox.svg" => [120, 90],
  "zero-width.svg" => [120, 60],
  "zero-height.svg" => [80, 90],
}
invalid_cases = %w[zero-no-viewbox.svg malformed.svg not-svg.svg cropped.png]
report = {
  operation: "upload_svg_dimensions",
  source: JSON.parse(File.read(Rails.root.join("source-manifest.json"))),
  ruby: RUBY_DESCRIPTION,
  kernel: `uname -sr`.strip,
  landlock: Landlock.supported?,
  libvips: DiscourseVips.version,
  imagemagick: ImageMagick.magick("--version", operation: :benchmark_version).lines.first.strip,
  nokogiri: Nokogiri::VERSION,
  gems: Gem.loaded_specs.transform_values { |spec| spec.version.to_s },
  timing_scope: "Operation calls only; no Rails boot. Warm runs reuse the Ruby process and libvips worker. ImageMagick starts a command for each call.",
  warm_iterations: iterations,
  cold_starts:,
  successful_inputs: [],
  invalid_inputs: [],
  compatibility_failures: [],
}

(success_cases.keys + invalid_cases).each do |filename|
  input_path = Rails.root.join("spec/fixtures/images", filename).to_s
  expected_dimensions = success_cases[filename]
  operations = {
    imagemagick: -> {
      ImageMagick.identify(
        "-ping", "-format", "%w,%h", "MSVG:#{input_path}",
        operation: :upload_svg_dimensions, read: [input_path], timeout: 5,
      ).strip.split(",").map { |value| Integer(value, 10) }
    },
    libvips: -> { DiscourseVips.svg_dimensions(input_path:, timeout: 5) },
  }
  warmup = operations.transform_values { |operation| measure_operation(operation) }
  measurements = { imagemagick: [], libvips: [] }
  iterations.times do |iteration|
    backends = iteration.even? ? operations.keys : operations.keys.reverse
    backends.each do |backend|
      measurements.fetch(backend) << measure_operation(operations.fetch(backend))
    end
  end

  mismatches = []
  measurements.each do |backend, runs|
    ([warmup.fetch(backend)] + runs).each_with_index do |measurement, index|
      outcome = measurement.fetch(:outcome)
      compatible =
        if expected_dimensions
          outcome[:status] == "ok" && outcome[:value] == expected_dimensions
        else
          outcome[:status] == "error"
        end
      mismatches << { backend:, run: index.zero? ? "warmup" : index, outcome: } if !compatible
    end
  end

  entry = {
    filename:,
    input_bytes: File.size(input_path),
    sha256: Digest::SHA256.file(input_path).hexdigest,
    expected: expected_dimensions ? { status: "ok", value: expected_dimensions } : { status: "error" },
    warmup:,
    warm: measurements.transform_values { |runs| distribution(runs) },
    outcomes: measurements.transform_values { |runs| runs.map { |run| run.fetch(:outcome) } },
    compatible: mismatches.empty?,
  }
  report[expected_dimensions ? :successful_inputs : :invalid_inputs] << entry
  if !mismatches.empty?
    report[:compatibility_failures] << { filename:, mismatches: }
  end
end

cold_filename = "fixed.svg"
input_path = Rails.root.join("spec/fixtures/images", cold_filename).to_s
cold_operation = -> { DiscourseVips.svg_dimensions(input_path:, timeout: 5) }
cold_measurements = cold_starts.times.map do
  DiscourseVips.before_fork
  measurement = measure_operation(cold_operation)
  DiscourseVips.before_fork
  measurement
end
report[:libvips_cold_start] = {
  filename: cold_filename,
  sha256: Digest::SHA256.file(input_path).hexdigest,
  scope: "Fresh worker creation and SVG request; Ruby bootstrap and operating-system cache reset excluded.",
  timings: distribution(cold_measurements),
  outcomes: cold_measurements.map { |measurement| measurement.fetch(:outcome) },
}
cold_measurements.each_with_index do |measurement, index|
  if measurement.fetch(:outcome) != { status: "ok", value: success_cases.fetch(cold_filename) }
    report[:compatibility_failures] << { filename: cold_filename, cold_run: index + 1, measurement: }
  end
end

result_path = ENV.fetch("RESULT_PATH", Rails.root.join("svg-dimensions-results.json").to_s)
FileUtils.mkdir_p(File.dirname(result_path))
File.write(result_path, JSON.pretty_generate(report) + "\n")
puts "SVG dimension evidence: #{result_path}"
abort "SVG dimension compatibility failures are recorded in #{result_path}" if report[:compatibility_failures].any?
