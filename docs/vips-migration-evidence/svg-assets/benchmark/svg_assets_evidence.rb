require "json"
require "digest"
require "fileutils"

Vips.cache_set_max(0)
Vips.concurrency_set(1)
output_directory = Rails.root.join("outputs")
FileUtils.mkdir_p(output_directory)
report = {
  operation: "svg_to_png", ruby: RUBY_DESCRIPTION,
  kernel: `uname -sr`.strip, landlock: Landlock.supported?,
  libvips: DiscourseVips.version,
  imagemagick: ImageMagick.magick("--version", operation: :benchmark_version).lines.first.strip,
  iterations: 31, samples: [], source: JSON.parse(File.read(Rails.root.join("source-manifest.json"))),
  excluded: { "massive.svg" => "75-megapixel dimension-probe fixture; not a representative OG asset" },
}
Dir.glob(Rails.root.join("inputs/*.svg")).sort.each do |input_path|
  name = File.basename(input_path, ".svg")
  next if name == "massive"
  outputs = %i[imagemagick libvips].to_h { |backend| [backend, output_directory.join("#{name}-#{backend}.png").to_s] }
  operations = {
    imagemagick: -> {
      ImageMagick.magick("MSVG:#{input_path}", outputs[:imagemagick], operation: :topic_og_asset_render, read: [input_path], write: [output_directory.to_s], timeout: 10)
    },
    libvips: -> { DiscourseVips.svg_to_png(input_path: input_path, output_path: outputs[:libvips], timeout: 10) },
  }
  failures = {}
  operations.each do |backend, operation|
    begin
      operation.call
    rescue StandardError => error
      failures[backend] = { class: error.class.name, message: error.message }
    end
  end
  sample = { name: name, sha256: Digest::SHA256.file(input_path).hexdigest, failures: failures }
  timings = { imagemagick: [], libvips: [] }
  if failures.empty?
    31.times do |iteration|
      (iteration.even? ? operations.keys : operations.keys.reverse).each do |backend|
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        operations.fetch(backend).call
        timings[backend] << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
      end
    end
    sample[:dimensions] = outputs.transform_values { |path| image = Vips::Image.pngload(path); [image.width, image.height] }
    sample[:output_bytes] = outputs.transform_values { |path| File.size(path) }
    sample[:output_sha256] = outputs.transform_values { |path| Digest::SHA256.file(path).hexdigest }
    sample[:warm] = timings.transform_values { |values| sorted = values.sort; { median_ms: sorted[sorted.length / 2], p95_ms: sorted[(sorted.length * 0.95).ceil - 1], values_ms: values } }
  end
  report[:samples] << sample
  File.write(ENV.fetch("RESULT_PATH"), JSON.pretty_generate(report))
end
DiscourseVips.before_fork
report[:libvips_fresh_worker_ms] = 5.times.map do
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  DiscourseVips.svg_to_png(input_path: Rails.root.join("inputs/gradient-logo.svg").to_s, output_path: output_directory.join("cold.png").to_s, timeout: 10)
  elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
  DiscourseVips.before_fork
  elapsed
end
File.write(ENV.fetch("RESULT_PATH"), JSON.pretty_generate(report))
