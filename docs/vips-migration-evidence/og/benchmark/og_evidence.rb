require "json"
require "digest"
require "fileutils"
require "open3"

output_directory = Rails.root.join("outputs")
FileUtils.mkdir_p(output_directory)
font_matches = ["Arial", "sans-serif:lang=zh-cn", "sans-serif:lang=ar"].to_h do |pattern|
  match, = Open3.capture2("fc-match", "-f", "%{family}|%{file}", pattern)
  family, path = match.split("|")
  [pattern, { family: family, path: path, sha256: Digest::SHA256.file(path).hexdigest }]
end
report = {
  operation: "topic_og_render", ruby: RUBY_DESCRIPTION,
  kernel: `uname -sr`.strip, landlock: Landlock.supported?,
  libvips: DiscourseVips.version, fonts: font_matches,
  imagemagick: ImageMagick.magick("--version", operation: :benchmark_version).lines.first.strip,
  iterations: 31, samples: [], source: JSON.parse(File.read(Rails.root.join("source-manifest.json"))),
  corpus: JSON.parse(File.read(Rails.root.join("inputs/manifest.json"))),
}
Dir.glob(Rails.root.join("inputs/*/og.svg")).sort.each do |input_path|
  Dir.chdir(File.dirname(input_path))
  name = File.basename(File.dirname(input_path))
  outputs = %i[imagemagick libvips].to_h { |backend| [backend, output_directory.join("#{name}-#{backend}.png").to_s] }
  operations = {
    imagemagick: -> {
      ImageMagick.magick("-background", "none", "-size", "1200x630", "MSVG:#{input_path}", "-depth", "8", "-define", "png:compression-level=9", outputs[:imagemagick], operation: :topic_og_render, read: [File.dirname(input_path)], write: [output_directory.to_s], nice: 10, timeout: 20)
    },
    libvips: -> { DiscourseVips.topic_og_render(input_path: input_path, output_path: outputs[:libvips], timeout: 20) },
  }
  operations.each_value(&:call)
  timings = { imagemagick: [], libvips: [] }
  31.times do |iteration|
    (iteration.even? ? operations.keys : operations.keys.reverse).each do |backend|
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      operations.fetch(backend).call
      timings[backend] << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
    end
  end
  headers = outputs.transform_values { |path| Vips::Image.pngload(path) }
  dimensions = headers.transform_values { |image| [image.width, image.height] }
  raise "unexpected OG dimensions" unless dimensions.values.all? { |value| value == [1200, 630] }
  report[:samples] << {
    name: name, sha256: Digest::SHA256.file(input_path).hexdigest, dimensions: dimensions,
    output_bytes: outputs.transform_values { |path| File.size(path) },
    output_sha256: outputs.transform_values { |path| Digest::SHA256.file(path).hexdigest },
    warm: timings.transform_values { |values| sorted = values.sort; { median_ms: sorted[sorted.length / 2], p95_ms: sorted[(sorted.length * 0.95).ceil - 1], values_ms: values } },
  }
  File.write(ENV.fetch("RESULT_PATH"), JSON.pretty_generate(report))
end
DiscourseVips.before_fork
input_path = Rails.root.join("inputs/cjk-dark/og.svg").to_s
report[:libvips_fresh_worker_ms] = 5.times.map do
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  DiscourseVips.topic_og_render(input_path: input_path, output_path: output_directory.join("cold.png").to_s, timeout: 20)
  elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
  DiscourseVips.before_fork
  elapsed
end
File.write(ENV.fetch("RESULT_PATH"), JSON.pretty_generate(report))
