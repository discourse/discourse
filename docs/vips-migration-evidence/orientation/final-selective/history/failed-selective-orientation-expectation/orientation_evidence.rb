require "json"
require "digest"
require "fileutils"

Vips.cache_set_max(0)
Vips.concurrency_set(1)
source_manifest = JSON.parse(File.read(Rails.root.join("source-manifest.json")))
source_manifest.fetch("files").merge(source_manifest.fetch("bundle_files")).each do |relative, expected|
  raise "benchmark source changed: #{relative}" unless Digest::SHA256.file(Rails.root.join(relative)).hexdigest == expected
end
cases = JSON.parse(File.read(Rails.root.join("cases.json")))
cases.each do |sample|
  next unless sample["sha256"]
  raise "input changed: #{sample.fetch("filename")}" unless Digest::SHA256.file(Rails.root.join("inputs", sample.fetch("filename"))).hexdigest == sample.fetch("sha256")
end
progressive = cases.find { |sample| sample["generated_from"] }
progressive_input = Rails.root.join("inputs", progressive.fetch("generated_from")).to_s
progressive_output = Rails.root.join("inputs", progressive.fetch("filename")).to_s
Discourse::SafeExec.capture(
  "jpegtran", "-copy", "all", "-progressive", "-outfile", progressive_output, progressive_input,
  read: [*Discourse::SafeExec.default_read_paths, "/etc/ld.so.cache", progressive_input],
  write: [File.dirname(progressive_output)],
  execute: Discourse::SafeExec.default_execute_paths,
  timeout: 20,
)

output_directory = Rails.root.join("outputs-final-selective")
FileUtils.mkdir_p(output_directory)
result_path = ENV.fetch("RESULT_PATH", Rails.root.join("final-selective.json").to_s)
report = {
  operation: "upload_auto_orient",
  timing_scope: "ImageMagick in-place JPEG auto-orient versus the current separate-output facade; input restoration, source-quality estimation, metadata validation, and output decoding excluded",
  caller_integration: "not included; measures worker transform only, excluding caller temporary-file adoption and legacy quality probe",
  iterations: 31,
  ruby: RUBY_DESCRIPTION,
  kernel: `uname -sr`.strip,
  landlock: Landlock.supported?,
  libvips: DiscourseVips.version,
  imagemagick: ImageMagick.magick("--version", operation: :benchmark_version).lines.first.strip,
  jpegtran_sha256: Digest::SHA256.file("/usr/bin/jpegtran").hexdigest,
  source: source_manifest,
  samples: [],
}
raise "production benchmark requires Landlock" unless report[:landlock]
metadata = lambda do |path|
  image = Vips::Image.jpegload(path)
  {
    dimensions: [image.width, image.height],
    orientation: image.get_typeof("orientation").zero? ? nil : image.get("orientation"),
    progressive: image.get_typeof("jpeg-multiscan") != 0 && image.get("jpeg-multiscan") != 0,
    icc_sha256: image.get_typeof("icc-profile-data").zero? ? nil : Digest::SHA256.hexdigest(image.get("icc-profile-data")),
  }
end
palette = { "red" => [255, 0, 0], "green" => [0, 255, 0], "blue" => [0, 0, 255], "cyan" => [0, 255, 255], "magenta" => [255, 0, 255], "yellow" => [255, 255, 0] }
source_qualities = {}
cases.each do |example|
  filename = example.fetch("filename")
  input_path = Rails.root.join("inputs", filename).to_s
  input_sha256 = Digest::SHA256.file(input_path).hexdigest
  input_metadata = metadata.call(input_path)
  raise "source orientation mismatch: #{filename}" unless input_metadata[:orientation] == example.fetch("orientation")
  raise "progressive fixture is not progressive" if example["generated_from"] && !input_metadata[:progressive]
  source_quality = Integer(ImageMagick.identify("-format", "%Q", "jpeg:#{input_path}", operation: :upload_auto_orient, read: [input_path], timeout: 5))
  source_qualities[filename] = source_quality
  outputs = %i[imagemagick libvips].to_h { |backend| [backend, output_directory.join("#{filename}-#{backend}.jpg").to_s] }
  prepare = ->(backend) { FileUtils.cp(input_path, outputs.fetch(backend)) if backend == :imagemagick }
  operations = {
    imagemagick: -> {
      path = outputs.fetch(:imagemagick)
      ImageMagick.magick("jpeg:#{path}", "-auto-orient", "jpeg:#{path}", operation: :upload_auto_orient, read: [path], write: [path, output_directory.to_s], timeout: 5)
    },
    libvips: -> { DiscourseVips.auto_orient(input_path:, output_path: outputs.fetch(:libvips), source_quality:, timeout: 5) },
  }
  operations.each do |backend, operation|
    prepare.call(backend)
    operation.call
  end
  timings = { imagemagick: [], libvips: [] }
  31.times do |iteration|
    (iteration.even? ? operations.keys : operations.keys.reverse).each do |backend|
      prepare.call(backend)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      operations.fetch(backend).call
      timings.fetch(backend) << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
    end
  end
  raise "source changed during transformation: #{filename}" unless Digest::SHA256.file(input_path).hexdigest == input_sha256
  expected_dimensions = example.fetch("orientation").to_i >= 5 ? input_metadata[:dimensions].reverse : input_metadata[:dimensions]
  output_metadata = outputs.transform_values { |path| metadata.call(path) }
  output_metadata.each do |backend, values|
    raise "dimensions differ: #{filename}/#{backend}" unless values[:dimensions] == expected_dimensions
    raise "orientation not normalized: #{filename}/#{backend}" unless [nil, 1].include?(values[:orientation])
    raise "ICC changed: #{filename}/#{backend}" unless values[:icc_sha256] == input_metadata[:icc_sha256]
  end
  decoded = outputs.to_h do |backend, path|
    decoded_path = output_directory.join("#{filename}-#{backend}-decoded.png").to_s
    ImageMagick.magick("jpeg:#{path}", "png:#{decoded_path}", operation: :upload_auto_orient, read: [path], write: [output_directory.to_s], timeout: 5)
    [backend, Vips::Image.pngload(decoded_path).colourspace(:srgb)]
  end
  layouts = {}
  if example["expected_layout"]
    expected_layout = example.fetch("expected_layout")
    decoded.each do |backend, image|
      layouts[backend] = expected_layout.each_with_index.map do |row, row_index|
        row.each_index.map do |column_index|
          actual = image.getpoint((column_index * 2 + 1) * image.width / (row.length * 2), (row_index * 2 + 1) * image.height / (expected_layout.length * 2)).first(3)
          palette.min_by { |_name, color| color.zip(actual).sum { |expected, channel| (expected - channel)**2 } }.first
        end
      end
      raise "color-grid layout differs: #{filename}/#{backend}" unless layouts[backend] == expected_layout
    end
  end
  difference = decoded.fetch(:imagemagick).cast(:float) - decoded.fetch(:libvips).cast(:float)
  mse = (difference * difference).avg
  report[:samples] << {
    filename:, source_quality:, quality_estimator: "ImageMagick identify %Q, outside transformation timing",
    input_sha256:, input_bytes: File.size(input_path), input_metadata:, output_metadata:, layouts:,
    progressive_preserved: output_metadata.transform_values { |values| values[:progressive] == input_metadata[:progressive] },
    output_sha256: outputs.transform_values { |path| Digest::SHA256.file(path).hexdigest },
    output_bytes: outputs.transform_values { |path| File.size(path) },
    pixels: { maximum_difference: difference.abs.max, mean_difference: difference.abs.avg, psnr_db: mse.zero? ? "identical" : 10 * Math.log10(255.0**2 / mse) },
    warm: timings.transform_values { |values| sorted = values.sort; { median_ms: sorted[15], p95_ms: sorted[29], values_ms: values } },
  }
  File.write(result_path, JSON.pretty_generate(report))
  puts JSON.generate(report[:samples].last)
end
fresh_filename = "photo-orientation-6.jpg"
input_path = Rails.root.join("inputs", fresh_filename).to_s
source_quality = source_qualities.fetch(fresh_filename)
report[:libvips_fresh_workers] = 5.times.map do |iteration|
  DiscourseVips.before_fork
  output_path = output_directory.join("fresh-worker-#{iteration}.jpg").to_s
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  DiscourseVips.auto_orient(input_path:, output_path:, source_quality:, timeout: 5)
  elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
  values = metadata.call(output_path)
  expected = report[:samples].find { |sample| sample[:filename] == fresh_filename }.fetch(:output_metadata).fetch(:libvips)
  raise "fresh-worker metadata differs" unless values == expected
  { elapsed_ms:, input_sha256: Digest::SHA256.file(input_path).hexdigest, output_sha256: Digest::SHA256.file(output_path).hexdigest, output_metadata: values }
end
DiscourseVips.before_fork
File.write(result_path, JSON.pretty_generate(report))
