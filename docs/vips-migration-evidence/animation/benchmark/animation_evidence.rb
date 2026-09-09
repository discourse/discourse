require "landlock"
require "json"
require "digest"

iterations = Integer(ENV.fetch("ITERATIONS", "30"))
filenames = %w[static.gif static.webp static.avif tiny_animated.gif animated.gif animated.webp multipage.avif]
report = {
  operation: "upload_animation_probe",
  ruby: RUBY_DESCRIPTION,
  kernel: `uname -sr`.strip,
  landlock: Landlock.supported?,
  libvips: DiscourseVips.version,
  imagemagick: ImageMagick.magick("--version", operation: :benchmark_version).lines.first.strip,
  iterations:,
  samples: [],
}

filenames.each do |filename|
  input_path = Rails.root.join("spec/fixtures/images", filename).to_s
  timings = { imagemagick: [], libvips: [] }
  values = {}
  operations = {
    imagemagick: -> {
      ImageMagick.identify(
        "-ping", "-format", "%n\\n", input_path,
        operation: :upload_animation_probe, read: [input_path], timeout: 5,
      ).to_i > 1
    },
    libvips: -> { DiscourseVips.animated?(input_path:, timeout: 5) },
  }
  operations.each_value(&:call)
  iterations.times do |iteration|
    backends = iteration.even? ? operations.keys : operations.keys.reverse
    backends.each do |backend|
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      values[backend] = operations.fetch(backend).call
      timings.fetch(backend) << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000
    end
  end
  raise "classification mismatch for #{filename}: #{values.inspect}" if values.values.uniq.size != 1
  distributions = timings.transform_values do |durations_ms|
    sorted = durations_ms.sort
    {
      median_ms: sorted[sorted.length / 2],
      p95_ms: sorted[[(sorted.length * 0.95).ceil - 1, sorted.length - 1].min],
      min_ms: sorted.first,
      max_ms: sorted.last,
      values_ms: durations_ms,
    }
  end
  report[:samples] << {
    filename:, input_bytes: File.size(input_path), sha256: Digest::SHA256.file(input_path).hexdigest,
    animated: values, warm: distributions,
  }
end

DiscourseVips.before_fork
cold_timings_ms = 5.times.map do
  input_path = Rails.root.join("spec/fixtures/images/animated.webp").to_s
  started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  DiscourseVips.animated?(input_path:, timeout: 5)
  duration_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000
  DiscourseVips.before_fork
  duration_ms
end
report[:libvips_cold_start_ms] = cold_timings_ms
File.write(ENV.fetch("RESULT_PATH"), JSON.pretty_generate(report))
