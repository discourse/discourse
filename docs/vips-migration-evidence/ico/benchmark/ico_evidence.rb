require "json"
require "digest"
require "fileutils"

output_directory = Rails.root.join("outputs")
FileUtils.mkdir_p(output_directory)
report = {
  operation: "upload_ico_conversion", ruby: RUBY_DESCRIPTION,
  kernel: `uname -sr`.strip, landlock: Landlock.supported?,
  libvips: DiscourseVips.version,
  imagemagick: ImageMagick.magick("--version", operation: :benchmark_version).lines.first.strip,
  iterations: 31, samples: [], source: JSON.parse(File.read(Rails.root.join("source-manifest.json"))),
}
Dir.glob(Rails.root.join("inputs/*")).sort.each do |input_path|
  filename = File.basename(input_path)
  outputs = %i[imagemagick libvips].to_h { |backend| [backend, output_directory.join("#{filename}-#{backend}.png").to_s] }
  operations = {
    imagemagick: -> {
      ImageMagick.magick("#{input_path}[-1]", "-auto-orient", "-background", "white", "-interlace", "none", outputs[:imagemagick], operation: :upload_format_conversion, read: [input_path], write: [output_directory.to_s], timeout: 20)
    },
    libvips: -> { DiscourseVips.ico_to_png(input_path: input_path, output_path: outputs[:libvips], timeout: 20) },
  }
  outcomes = {}
  measured_operations = operations.transform_values do |operation|
    -> {
      begin
        operation.call
        { status: "ok" }
      rescue StandardError => error
        { status: "error", error_class: error.class.name, message: error.message }
      end
    }
  end
  measured_operations.each { |backend, operation| outcomes[backend] = operation.call }
  timings = { imagemagick: [], libvips: [] }
  31.times do |iteration|
    (iteration.even? ? operations.keys : operations.keys.reverse).each do |backend|
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      outcome = measured_operations.fetch(backend).call
      timings[backend] << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
      raise "outcome changed #{filename}" unless outcome[:status] == outcomes[backend][:status]
    end
  end
  sample = {
    filename: filename, sha256: Digest::SHA256.file(input_path).hexdigest,
    input_bytes: File.size(input_path), outcomes: outcomes,
    warm: timings.transform_values { |values| sorted = values.sort; { median_ms: sorted[sorted.length / 2], p95_ms: sorted[(sorted.length * 0.95).ceil - 1], values_ms: values } },
  }
  if outcomes.values.all? { |outcome| outcome[:status] == "ok" }
    images = outputs.transform_values { |path| Vips::Image.pngload(path).colourspace(:srgb) }
    sample[:dimensions] = images.transform_values { |image| [image.width, image.height] }
    raise "dimensions differ #{filename}" unless sample[:dimensions].values.uniq.length == 1
    normalized = images.transform_values { |image| image.has_alpha? ? image : image.bandjoin(255) }
    difference = (normalized[:imagemagick].cast(:float) - normalized[:libvips].cast(:float)).abs
    sample[:maximum_channel_difference] = difference.max
    sample[:mean_channel_difference] = difference.avg
  end
  sample[:output_sha256] = outputs.filter_map { |backend, path| [backend, Digest::SHA256.file(path).hexdigest] if outcomes[backend][:status] == "ok" }.to_h
  report[:samples] << sample
  File.write(ENV.fetch("RESULT_PATH"), JSON.pretty_generate(report))
end
DiscourseVips.before_fork
input_path = Rails.root.join("inputs/ico-last-bmp.ico").to_s
report[:libvips_fresh_worker_ms] = 5.times.map do
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  DiscourseVips.ico_to_png(input_path: input_path, output_path: output_directory.join("cold.png").to_s, timeout: 20)
  elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
  DiscourseVips.before_fork
  elapsed
end
File.write(ENV.fetch("RESULT_PATH"), JSON.pretty_generate(report))
