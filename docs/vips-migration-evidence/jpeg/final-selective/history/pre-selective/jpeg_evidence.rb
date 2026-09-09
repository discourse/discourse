require "json"
require "digest"
require "fileutils"

Vips.cache_set_max(0)
Vips.concurrency_set(1)
output_directory = Rails.root.join("outputs")
FileUtils.mkdir_p(output_directory)
report = {
  operation: "upload_jpeg_conversion", quality: 75, ruby: RUBY_DESCRIPTION,
  kernel: `uname -sr`.strip, landlock: Landlock.supported?,
  libvips: DiscourseVips.version,
  imagemagick: ImageMagick.magick("--version", operation: :benchmark_version).lines.first.strip,
  samples: [], source: JSON.parse(File.read(Rails.root.join("source-manifest.json"))),
}
result_path = ENV.fetch("RESULT_PATH")
if File.exist?(result_path)
  previous = JSON.parse(File.read(result_path), symbolize_names: true)
  raise "benchmark source changed" unless previous[:source] == report[:source].transform_keys(&:to_sym).transform_values { |value| value.is_a?(Hash) ? value.transform_keys(&:to_sym) : value }
  report[:samples] = previous[:samples]
end
Dir.glob(Rails.root.join("inputs/*")).sort.each do |input_path|
  filename = File.basename(input_path)
  next if report[:samples].any? { |sample| sample[:filename] == filename }
  input_format = File.extname(input_path).delete_prefix(".")
  input_format = "jpeg" if input_format == "jpg"
  iterations = filename == "stress.jpg" ? 7 : 31
  outputs = %i[imagemagick libvips].to_h { |backend| [backend, output_directory.join("#{filename}-#{backend}.jpg").to_s] }
  operations = {
    imagemagick: -> {
      ImageMagick.magick("#{input_format}:#{input_path}", "-auto-orient", "-background", "white", "-interlace", "none", "-flatten", "-quality", "75", "jpg:#{outputs[:imagemagick]}", operation: :upload_format_conversion, read: [input_path], write: [output_directory.to_s], timeout: 20)
    },
    libvips: -> { DiscourseVips.convert_to_jpeg(input_path: input_path, output_path: outputs[:libvips], input_format: input_format, quality: 75, timeout: 20) },
  }
  if filename == "stress.jpg"
    outcomes = operations.transform_values do |operation|
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      begin
        operation.call
        { status: "ok", elapsed_ms: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000 }
      rescue StandardError => error
        { status: "error", elapsed_ms: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000, error: error.message }
      end
    end
    report[:samples] << { filename: filename, sha256: Digest::SHA256.file(input_path).hexdigest, input_bytes: File.size(input_path), single_stress_attempt: outcomes }
    File.write(result_path, JSON.pretty_generate(report))
    next
  end
  operations.each_value(&:call)
  timings = { imagemagick: [], libvips: [] }
  iterations.times do |iteration|
    (iteration.even? ? operations.keys : operations.keys.reverse).each do |backend|
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      operations.fetch(backend).call
      timings[backend] << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
    end
  end
  headers = outputs.transform_values { |path| Vips::Image.jpegload(path, access: :sequential) }
  dimensions = headers.transform_values { |image| [image.width, image.height] }
  raise "dimensions differ #{filename}" unless dimensions.values.uniq.length == 1
  profiles = headers.transform_values { |image| image.get_typeof("icc-profile-data").zero? ? nil : Digest::SHA256.hexdigest(image.get("icc-profile-data")) }
  raise "ICC differs #{filename}" unless profiles.values.uniq.length == 1
  report[:samples] << {
    filename: filename, sha256: Digest::SHA256.file(input_path).hexdigest,
    input_bytes: File.size(input_path), iterations: iterations, dimensions: dimensions, icc_sha256: profiles,
    output_bytes: outputs.transform_values { |path| File.size(path) },
    output_sha256: outputs.transform_values { |path| Digest::SHA256.file(path).hexdigest },
    warm: timings.transform_values { |values| sorted = values.sort; { median_ms: sorted[sorted.length / 2], p95_ms: sorted[(sorted.length * 0.95).ceil - 1], values_ms: values } },
  }
  File.write(ENV.fetch("RESULT_PATH"), JSON.pretty_generate(report))
end
DiscourseVips.before_fork
input_path = Rails.root.join("inputs/photo.jpg").to_s
report[:libvips_fresh_worker_ms] = 5.times.map do
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  DiscourseVips.convert_to_jpeg(input_path: input_path, output_path: output_directory.join("cold.jpg").to_s, input_format: "jpeg", quality: 75, timeout: 20)
  elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
  DiscourseVips.before_fork
  elapsed
end
File.write(ENV.fetch("RESULT_PATH"), JSON.pretty_generate(report))
