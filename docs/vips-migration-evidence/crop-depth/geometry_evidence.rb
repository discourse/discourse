require "json"
require "digest"
require "fileutils"

raise "Landlock is required for this benchmark" if !Landlock.supported?
Vips.cache_set_max(0)
Vips.concurrency_set(1)

def run_transform(operation:, backend:, sample:, input_path:, output_path:, quality:)
  if backend == :imagemagick
    instructions = sample.fetch("instructions").map do |argument|
      case argument
      when "@INPUT@"
        "#{sample.fetch("input_format")}:#{input_path}[0]"
      when "@OUTPUT@"
        "#{sample.fetch("output_format")}:#{output_path}"
      when "@PROFILE@"
        Rails.root.join("vendor/data/RT_sRGB.icm").to_s
      else
        argument
      end
    end
    ImageMagick.magick(*instructions, operation: :"optimized_image_#{operation}", read: [input_path], write: [File.dirname(output_path)], timeout: 20, nice: 10)
  else
    arguments = { input_path:, output_path:, input_format: sample.fetch("input_format"), output_format: sample.fetch("output_format"), quality:, timeout: 20 }
    if operation == "downsize"
      DiscourseVips.downsize(**arguments, geometry: sample.fetch("geometry"))
    else
      arguments.merge!(width: sample.fetch("width"), height: sample.fetch("height"), strip_metadata: sample.fetch("strip_metadata"))
      if operation == "crop"
        DiscourseVips.crop(**arguments)
      else
        DiscourseVips.resize(**arguments)
      end
    end
  end
end

def quality_for(sample:, input_path:)
  return { value: sample.fetch("quality"), source: "explicit recorded option" } if sample["quality"]
  output_format = sample.fetch("output_format")
  return { value: 50, source: "AVIF default" } if output_format == "avif"
  return { value: nil, source: "encoder quality not used" } if !%w[jpg jpeg webp].include?(output_format)

  source_quality = nil
  probe = nil
  input_format = sample.fetch("input_format")
  if %w[jpg jpeg webp].include?(input_format)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    estimated_quality = ImageMagick.identify("-ping", "-format", "%Q", "#{input_format}:#{input_path}[0]", operation: :upload_quality_probe, read: [input_path], timeout: 20).to_i
    probe = { backend: "ImageMagick identify frame0", estimated_quality:, elapsed_ms: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000 }
    source_quality = estimated_quality if input_format != "webp" || estimated_quality == 100
  end
  { value: source_quality || (output_format == "webp" ? 75 : 92), source: source_quality ? "source quality" : "encoder default", probe: }
end

def image_evidence(path:, output_format:, decoded_path:, operation:)
  details = ImageMagick.identify("-format", "%m\t%w\t%h\t%z\t%[colorspace]\t%[channels]\t%[orientation]\t%[profiles]", "#{output_format}:#{path}[0]", operation: :"optimized_image_#{operation}", read: [path], timeout: 20)
  ImageMagick.magick("#{output_format}:#{path}[0]", "png:#{decoded_path}", operation: :"optimized_image_#{operation}", read: [path], write: [File.dirname(decoded_path)], timeout: 20)
  decoded = Vips::Image.pngload(decoded_path)
  profile = decoded.get_typeof("icc-profile-data") != 0 ? decoded.get("icc-profile-data") : nil
  {
    path: Pathname.new(path).relative_path_from(Rails.root).to_s,
    bytes: File.size(path), sha256: Digest::SHA256.file(path).hexdigest,
    identify: details, dimensions: [decoded.width, decoded.height], decoded_format: decoded.format,
    decoded_icc: profile ? { bytes: profile.bytesize, sha256: Digest::SHA256.hexdigest(profile) } : nil,
    decoded_exif_bytes: decoded.get_typeof("exif-data") != 0 ? decoded.get("exif-data").bytesize : 0,
    decoded_path: Pathname.new(decoded_path).relative_path_from(Rails.root).to_s,
  }
end

def compare_pixels(reference_path:, actual_path:)
  reference = Vips::Image.pngload(reference_path).colourspace(:srgb)
  actual = Vips::Image.pngload(actual_path).colourspace(:srgb)
  return { dimensions_match: false } if reference.width != actual.width || reference.height != actual.height

  reference = reference.addalpha if !reference.has_alpha?
  actual = actual.addalpha if !actual.has_alpha?
  alpha_difference = (reference[3].cast(:float) - actual[3].cast(:float)).abs
  visible = [0, 255].map do |background|
    reference_flat = reference.flatten(background: [background, background, background])
    actual_flat = actual.flatten(background: [background, background, background])
    difference = reference_flat.cast(:float) - actual_flat.cast(:float)
    mse = (difference * difference).avg
    { background:, mean_difference: difference.abs.avg, maximum_difference: difference.abs.max, psnr_db: mse.zero? ? "identical" : 10 * Math.log10(255.0**2 / mse) }
  end
  { dimensions_match: true, alpha_mean_difference: alpha_difference.avg, alpha_maximum_difference: alpha_difference.max, visible_composites: visible }
end

def timing_summary(values)
  sorted = values.sort
  { values_ms: values, median_ms: sorted[sorted.length / 2], p95_ms: sorted[(sorted.length * 0.95).ceil - 1] }
end

operation = ENV.fetch("OPERATION")
raise "OPERATION must be downsize, crop, or resize" if !%w[downsize crop resize].include?(operation)
manifest_path = Rails.root.join("manifest.json")
manifest = JSON.parse(File.read(manifest_path))
manifest.fetch("source").fetch("files").each do |relative, expected|
  raise "source changed: #{relative}" if Digest::SHA256.file(Rails.root.join(relative)).hexdigest != expected
end
manifest.fetch("inputs").each do |relative, metadata|
  raise "input changed: #{relative}" if Digest::SHA256.file(Rails.root.join(relative)).hexdigest != metadata.fetch("sha256")
end
samples = manifest.fetch("cases").select { |sample| sample.fetch("operation") == operation }
samples.select! { |sample| sample.fetch("name") == ENV["SAMPLE"] } if ENV["SAMPLE"]
raise "no matching samples" if samples.empty?
output_directory = Rails.root.join("outputs", operation)
FileUtils.mkdir_p(output_directory)
result_path = ENV.fetch("RESULT_PATH", Rails.root.join("#{operation}-results.json").to_s)
report = {
  process_uid: Process.uid, process_euid: Process.euid, image_digest: ENV.fetch("BENCH_IMAGE_DIGEST"),
  operation:, iterations: 31, source: manifest.fetch("source"), manifest_sha256: Digest::SHA256.file(manifest_path).hexdigest,
  harness_sha256: Digest::SHA256.file(__FILE__).hexdigest, ruby: RUBY_DESCRIPTION, kernel: `uname -sr`.strip,
  landlock: Landlock.supported?, libvips: DiscourseVips.version,
  imagemagick: ImageMagick.magick("--version", operation: :benchmark_version).lines.first.strip,
  timing_boundary: "Core transform including wrapper, IPC, sandbox child, priority10 and encoder. Excludes Rails boot, source quality probe, evidence decoding, and FileHelper optimizer.",
  quality_policy: manifest.fetch("quality_policy"), selected_sample: ENV["SAMPLE"],
  missing_baseline_fields: manifest.fetch("missing_baseline_fields").select { |sample| sample.fetch("operation") == operation },
  removed_api_cases: manifest.fetch("removed_api_cases"),
  limitations: manifest.fetch("historical_reference_limitations") + ["Visible pixel differences use ImageMagick-decoded PNGs converted to8-bit sRGB; original encoding/depth/profile metadata is recorded separately. Hidden RGB under transparent pixels is excluded from visible differences.", "Post-optimizer and complete caller evidence must be measured separately."],
  samples: [],
}
if File.exist?(result_path)
  previous = JSON.parse(File.read(result_path), symbolize_names: true)
  %i[operation manifest_sha256 harness_sha256 selected_sample].each do |field|
    raise "resume fingerprint differs: #{field}" if previous[field] != report[field]
  end
  report[:samples] = previous.fetch(:samples)
end
samples.each do |sample|
  name = sample.fetch("name")
  next if report[:samples].any? { |result| result[:name] == name }
  input_path = Rails.root.join(sample.fetch("input")).to_s
  output_paths = %i[imagemagick libvips].to_h { |backend| [backend, output_directory.join("#{name}-#{backend}.#{sample.fetch("output_suffix")}").to_s] }
  result = { name:, parameters: sample, input_sha256: manifest.fetch("inputs").fetch(sample.fetch("input")).fetch("sha256"), eligible_for_paired_timing: false }
  begin
    result[:quality] = quality_for(sample:, input_path:)
    quality = result[:quality].fetch(:value)
    validations = {}
    output_paths.each do |backend, output_path|
      FileUtils.rm_f(output_path)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      begin
        run_transform(operation:, backend:, sample:, input_path:, output_path:, quality:)
        elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
        dimensions = ImageMagick.identify("-ping", "-format", "%w,%h", "#{sample.fetch("output_format")}:#{output_path}[0]", operation: :"optimized_image_#{operation}", read: [output_path], timeout: 20).strip.split(",").map(&:to_i)
        validations[backend] = { status: "ok", elapsed_ms:, dimensions: }
      rescue StandardError => error
        validations[backend] = { status: "error", elapsed_ms: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000, error: { class: error.class.name, message: error.message } }
      end
    end
    result[:initial_validation] = validations
    result[:initial_dimensions_match] = validations.values.all? { |validation| validation[:status] == "ok" } && validations.values.map { |validation| validation[:dimensions] }.uniq.length == 1
    result[:expected_dimensions_match] = !sample["expected_dimensions"] || validations.values.all? { |validation| validation[:dimensions] == sample.fetch("expected_dimensions") }
    if result[:initial_dimensions_match] && result[:expected_dimensions_match]
      timings = { imagemagick: [], libvips: [] }
      begin
        31.times do |iteration|
          order = iteration.even? ? output_paths.keys : output_paths.keys.reverse
          order.each do |backend|
            started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            run_transform(operation:, backend:, sample:, input_path:, output_path: output_paths.fetch(backend), quality:)
            timings.fetch(backend) << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
          end
        end
        result[:warm] = timings.transform_values { |values| timing_summary(values) }
        result[:eligible_for_paired_timing] = true
      rescue StandardError => error
        result[:incomplete_warm_values_ms] = timings
        result[:warm_error] = { class: error.class.name, message: error.message }
      end
    end
    result[:outputs] = {}
    output_paths.each do |backend, output_path|
      next if validations.fetch(backend)[:status] != "ok" || !File.exist?(output_path)
      decoded_path = output_directory.join("#{name}-#{backend}-decoded.png").to_s
      begin
        result[:outputs][backend] = image_evidence(path: output_path, output_format: sample.fetch("output_format"), decoded_path:, operation:)
      rescue StandardError => error
        result[:outputs][backend] = { evidence_error: { class: error.class.name, message: error.message } }
        result[:eligible_for_paired_timing] = false
      end
    end
    if result[:outputs].values.count { |output| output[:decoded_path] } == 2
      result[:pixels] = compare_pixels(reference_path: Rails.root.join(result[:outputs][:imagemagick][:decoded_path]).to_s, actual_path: Rails.root.join(result[:outputs][:libvips][:decoded_path]).to_s)
      result[:eligible_for_paired_timing] = false if !result[:pixels][:dimensions_match]
    end
  rescue StandardError => error
    result[:error] = { class: error.class.name, message: error.message }
    result[:eligible_for_paired_timing] = false
  end
  report[:samples] << result
  File.write(result_path, JSON.pretty_generate(report))
  puts JSON.generate(name:, eligible_for_paired_timing: result[:eligible_for_paired_timing], validation: result[:initial_validation], error: result[:error])
end
eligible_names = report[:samples].select { |sample| sample[:eligible_for_paired_timing] }.map { |sample| sample[:name] }
cold_candidates = samples.select { |sample| eligible_names.include?(sample.fetch("name")) }
cold_sample = cold_candidates.find { |sample| sample.fetch("name").start_with?("natural-photo") } || cold_candidates.first
if cold_sample
  cold_input_path = Rails.root.join(cold_sample.fetch("input")).to_s
  cold_quality = quality_for(sample: cold_sample, input_path: cold_input_path)
  report[:fresh_worker] = { sample: cold_sample.fetch("name"), quality: cold_quality, measurements: [] }
  5.times do |iteration|
    DiscourseVips.before_fork
    output_path = output_directory.join("cold-#{iteration}.#{cold_sample.fetch("output_suffix")}").to_s
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    begin
      run_transform(operation:, backend: :libvips, sample: cold_sample, input_path: cold_input_path, output_path:, quality: cold_quality.fetch(:value))
      report[:fresh_worker][:measurements] << { status: "ok", elapsed_ms: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000, sha256: Digest::SHA256.file(output_path).hexdigest }
    rescue StandardError => error
      report[:fresh_worker][:measurements] << { status: "error", elapsed_ms: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000, error: { class: error.class.name, message: error.message } }
    end
  end
  DiscourseVips.before_fork
else
  report[:fresh_worker] = { skipped: "no compatible successful sample" }
end
report[:summary] = { selected: samples.length, recorded: report[:samples].length, paired_timing_eligible: report[:samples].count { |sample| sample[:eligible_for_paired_timing] }, incompatible_or_failed: report[:samples].reject { |sample| sample[:eligible_for_paired_timing] }.map { |sample| sample[:name] } }
File.write(result_path, JSON.pretty_generate(report))
puts result_path
