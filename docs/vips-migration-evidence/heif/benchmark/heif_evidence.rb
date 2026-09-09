require "json"
require "digest"
require "fileutils"

iterations = Integer(ENV.fetch("ITERATIONS", "31"))
output_directory = Rails.root.join("outputs")
FileUtils.mkdir_p(output_directory)
report = {
  operation: "upload_heif_conversion", ruby: RUBY_DESCRIPTION,
  kernel: `uname -sr`.strip, landlock: Landlock.supported?,
  libvips: DiscourseVips.version,
  imagemagick: ImageMagick.magick("--version", operation: :benchmark_version).lines.first.strip,
  iterations: iterations, samples: [],
  source_sha256: JSON.parse(File.read(Rails.root.join("source-manifest.json"))),
}
Dir.glob(Rails.root.join("spec/fixtures/images/*.heic")).sort.each do |input_path|
  filename = File.basename(input_path)
  outputs = %i[imagemagick libvips].to_h { |backend| [backend, output_directory.join("#{filename}-#{backend}.jpg").to_s] }
  operations = {
    imagemagick: -> {
      ImageMagick.magick(input_path, "-auto-orient", "-background", "white", "-interlace", "none", "-flatten", outputs[:imagemagick], operation: :upload_format_conversion, read: [input_path], write: [output_directory.to_s], timeout: 20)
    },
    libvips: -> { DiscourseVips.heif_to_jpeg(input_path: input_path, output_path: outputs[:libvips], timeout: 20) },
  }
  operations.each_value(&:call)
  timings = { imagemagick: [], libvips: [] }
  iterations.times do |iteration|
    (iteration.even? ? operations.keys : operations.keys.reverse).each do |backend|
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      operations.fetch(backend).call
      timings[backend] << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
    end
  end
  images = outputs.transform_values { |path| Vips::Image.jpegload(path) }
  dimensions = images.transform_values { |image| [image.width, image.height] }
  raise "dimensions differ #{filename}" unless dimensions.values.uniq.length == 1
  difference = (images[:imagemagick].cast(:float) - images[:libvips].cast(:float)).abs
  report[:samples] << {
    filename: filename, sha256: Digest::SHA256.file(input_path).hexdigest,
    input_bytes: File.size(input_path), dimensions: dimensions,
    output_bytes: outputs.transform_values { |path| File.size(path) },
    maximum_channel_difference: difference.max, mean_channel_difference: difference.avg,
    output_sha256: outputs.transform_values { |path| Digest::SHA256.file(path).hexdigest },
    warm: timings.transform_values { |values| sorted = values.sort; { median_ms: sorted[sorted.length / 2], p95_ms: sorted[(sorted.length * 0.95).ceil - 1], values_ms: values } },
  }
end
DiscourseVips.before_fork
input_path = Rails.root.join("spec/fixtures/images/should_be_jpeg.heic").to_s
report[:libvips_fresh_worker_ms] = 5.times.map do
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  DiscourseVips.heif_to_jpeg(input_path: input_path, output_path: output_directory.join("cold.jpg").to_s, timeout: 20)
  elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
  DiscourseVips.before_fork
  elapsed
end
File.write(ENV.fetch("RESULT_PATH"), JSON.pretty_generate(report))
