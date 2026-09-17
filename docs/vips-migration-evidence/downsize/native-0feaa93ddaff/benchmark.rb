# frozen_string_literal: true

require "digest"
require "English"
require "fileutils"
require "json"
require "open-uri"
require "pathname"

raise "Run with bin/rails runner" if !defined?(Rails.application) || !Rails.application.initialized?

source_head = ENV.fetch("SOURCE_HEAD")
source_sha256 = JSON.parse(ENV.fetch("SOURCE_SHA256"))
source_sha256.each do |path, expected|
  raise "Source does not match #{source_head}: #{path}" unless Digest::SHA256.file(Rails.root.join(path)).hexdigest == expected
end

codec_corpus_commit = "8e10d4d765667c1c49d74413878fc4bfb46dcf8d"
input_directory = Rails.root.join("tmp/downsize-native-inputs")
output_directory = Rails.root.join("tmp/downsize-native-results/outputs")
FileUtils.mkdir_p(input_directory)
FileUtils.mkdir_p(output_directory)

source_paths = {
  jpeg: %w[
    jpeg-conformance/valid/ycck.jpg
    jpeg-conformance/valid/rgb.jpg
    jpeg-conformance/valid/mjpeg.jpg
    jpeg-conformance/valid/progressive3.jpg
    jpeg-conformance/valid/blank_800x280.jpg
    jpeg-conformance/valid/grayscale_large.jpg
    jpeg-conformance/valid/16bit-qtables.jpg
    jpeg-conformance/valid/Canon_40D.jpg
    jpeg-conformance/valid/cmyk_logo.jpg
    jpeg-conformance/valid/extraneous-data.jpg
    jpeg-conformance/valid/grayscale_16x24_sampling2x2.jpg
    jpeg-conformance/valid/Fujifilm_FinePix_E500.jpg
    jpeg-conformance/valid/Nikon_D70.jpg
    jpeg-conformance/valid/progressive_rst_420.jpg
    jpeg-conformance/valid/restarts.jpg
  ],
  png: %w[
    CID22/CID22-512/validation/1025469.png
    CID22/CID22-512/validation/1044329.png
    CID22/CID22-512/validation/1189261.png
    CID22/CID22-512/validation/1279330.png
    CID22/CID22-512/validation/1418519.png
    CID22/CID22-512/validation/1420710.png
    CID22/CID22-512/validation/1475938.png
    CID22/CID22-512/validation/1531677.png
    CID22/CID22-512/validation/1544947.png
    CID22/CID22-512/validation/159550.png
    CID22/CID22-512/validation/1624487.png
    CID22/CID22-512/validation/162520.png
    CID22/CID22-512/validation/164595.png
    CID22/CID22-512/validation/2079234.png
    CID22/CID22-512/validation/2190188.png
  ],
}.freeze

corpus_inputs =
  source_paths
    .flat_map do |format, paths|
      paths.map do |source_path|
        path = input_directory.join(format.to_s, File.basename(source_path))
        if !path.exist?
          FileUtils.mkdir_p(path.dirname)
          url =
            "https://raw.githubusercontent.com/imazen/codec-corpus/#{codec_corpus_commit}/#{source_path}"
          URI.open(url) { |source| path.binwrite(source.read) }
        end

        {
          id: "#{format}-#{File.basename(source_path, ".*")}",
          format:,
          source_path:,
          path: path.to_s,
          input_bytes: path.size,
          input_sha256: Digest::SHA256.file(path).hexdigest,
        }
      end
    end
    .freeze

fixture_inputs = %w[static.gif tiny_animated.gif static.webp animated.webp static.avif multipage.avif tiny.svg dominant-color-semitransparent.png dominant-color-low-alpha-16bit.png].map do |filename|
  format = File.extname(filename).delete_prefix(".").to_sym
  source_path = "spec/fixtures/images/#{filename}"
  path = input_directory.join("fixtures", filename)
  FileUtils.mkdir_p(path.dirname)
  FileUtils.cp(Rails.root.join(source_path), path)
  {
    id: "fixture-#{format}-#{File.basename(filename, ".*")}",
    format: format,
    source_path: source_path,
    path: path.to_s,
    input_bytes: path.size,
    input_sha256: Digest::SHA256.file(path).hexdigest,
  }
end

require Rails.root.join("spec/support/image_orientation_helpers")
orientation_helper = Object.new.extend(ImageOrientationHelpers)
orientation_helper.send(:with_jpeg_orientation, source_path: Rails.root.join("spec/fixtures/images/exif_orientation.jpg"), orientation: 6) do |file|
  path = input_directory.join("fixtures", "orientation-6.jpg")
  FileUtils.cp(file.path, path)
  fixture_inputs << {
    id: "fixture-orientation-6",
    format: :jpeg,
    source_path: "spec/fixtures/images/exif_orientation.jpg (EXIF orientation 6 inserted by ImageOrientationHelpers)",
    path: path.to_s,
    input_bytes: path.size,
    input_sha256: Digest::SHA256.file(path).hexdigest,
  }
end

geometries = ["50%", "100x100>", "10000@"]
targets = [{ scale: 0.5 }, { width: 100, height: 100 }, { max_pixels: 10_000 }]
inputs = corpus_inputs.each_with_index.map do |input, index|
  input.merge(case_id: "#{input.fetch(:id)}-#{index % 3}", geometry: geometries[index % 3], target: targets[index % 3])
end + fixture_inputs.flat_map do |input|
  geometries.each_with_index.map do |geometry, index|
    input.merge(case_id: "#{input.fetch(:id)}-#{index}", geometry: geometry, target: targets[index])
  end
end
inputs = inputs.select { |input| input.fetch(:case_id).include?(ENV.fetch("BENCHMARK_FILTER")) } if ENV.key?("BENCHMARK_FILTER")

iterations = Integer(ENV.fetch("BENCHMARK_ITERATIONS", "101"))
memory_iterations = Integer(ENV.fetch("BENCHMARK_MEMORY_ITERATIONS", "101"))
memory_poll_seconds = 0.001

def process_tree_pids(pid)
  pids = [pid]
  pids.each do |current|
    children =
      Dir
        .glob("/proc/#{current}/task/*/children")
        .flat_map do |path|
          File.read(path).split.map(&:to_i)
        rescue Errno::ENOENT, Errno::ESRCH
          []
        end
    pids.concat(children.uniq.reject { |child| pids.include?(child) })
  rescue Errno::ENOENT, Errno::ESRCH
  end
  pids
end

def process_tree_memory(pid)
  processes =
    process_tree_pids(pid).filter_map do |current|
      values =
        File
          .read("/proc/#{current}/smaps_rollup")
          .lines
          .filter_map do |line|
            match = line.match(/^(Rss|Pss):\s+(\d+)/)
            [match[1], match[2].to_i * 1024] if match
          end
          .to_h
      { pid: current, rss_bytes: values.fetch("Rss"), pss_bytes: values.fetch("Pss") }
    rescue Errno::ENOENT, Errno::ESRCH
      nil
    end
  {
    rss_bytes: processes.sum { |process| process.fetch(:rss_bytes) },
    pss_bytes: processes.sum { |process| process.fetch(:pss_bytes) },
    processes:,
  }
end

def idle_memory(pid, backend:)
  expected_processes = backend == :libvips ? 2 : 1
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2
  loop do
    memory = process_tree_memory(pid)
    return memory if memory.fetch(:processes).length == expected_processes
    if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      raise "Conversion processes did not exit"
    end

    sleep 0.001
  end
end

def downsize(input, output_path)
  success = OptimizedImage.downsize(
    from: input.fetch(:path),
    to: output_path,
    **input.fetch(:target),
    format: true,
    filename: File.basename(output_path),
    raise_on_error: true,
  )
  raise "Downsize did not complete" unless success
end

results = []

%i[imagemagick libvips].each do |backend|
  output, child_output = IO.pipe
  child_control, control = IO.pipe

  pid =
    fork do
      output.close
      control.close
      child_output.sync = true
      vips_enabled = backend == :libvips
      GlobalSetting.instance_variable_set(:@enable_vips_image_processing_cache, vips_enabled)
      if GlobalSetting.enable_vips_image_processing != vips_enabled
        raise "Unable to select benchmark backend"
      end
      DiscourseVips.version if vips_enabled

      inputs.each do |input|
        output_format = input.fetch(:format) == :svg ? :png : input.fetch(:format)
        output_format = :jpg if output_format == :jpeg
        output_path = output_directory.join("#{input.fetch(:case_id)}-#{backend}.#{output_format}").to_s
        operation = -> { downsize(input, output_path) }

        begin
          operation.call
        rescue StandardError => error
          child_output.puts(JSON.generate(backend: backend, case_id: input.fetch(:case_id), status: "error", error: "#{error.class}: #{error.message}"))
          raise "Next input was not acknowledged" unless child_control.gets == "next\n"
          next
        end
        timings =
          Array.new(iterations) do
            started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            operation.call
            (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
          end
        child_output.puts(
          JSON.generate(
            backend:,
            id: input.fetch(:id),
            case_id: input.fetch(:case_id),
            geometry: input.fetch(:geometry),
            dimensions: FastImage.size(output_path),
            output_sha256: Digest::SHA256.file(output_path).hexdigest,
            format: input.fetch(:format),
            source_path: input.fetch(:source_path),
            input_bytes: input.fetch(:input_bytes),
            input_sha256: input.fetch(:input_sha256),
            output: output_path,
            output_bytes: File.size(output_path),
            median_ms: timings.sort.fetch(iterations / 2),
            timings_ms: timings,
          ),
        )

        memory_iterations.times do
          raise "Memory phase was not acknowledged" unless child_control.gets == "measure\n"

          operation.call
          child_output.puts("done")
        end
        raise "Next input was not acknowledged" unless child_control.gets == "next\n"
      end

      DiscourseVips.before_fork if backend == :libvips
      exit! 0
    end

  child_output.close
  child_control.close
  control.sync = true
  warm_worker_pid = nil

  inputs.each do |input|
    row = JSON.parse(output.gets || raise("Benchmark child exited unexpectedly"))
    if row["status"] == "error"
      results << row
      warn "#{backend}: #{input.fetch(:case_id)} failed: #{row.fetch("error")}"
      control.puts("next")
      next
    end
    memory =
      Array.new(memory_iterations) do
        baseline = idle_memory(pid, backend:)
        worker = baseline.fetch(:processes).find { |process| process.fetch(:pid) != pid }
        if backend == :libvips
          raise "Warm worker is missing" unless worker
          warm_worker_pid ||= worker.fetch(:pid)
          raise "Warm worker restarted" unless worker.fetch(:pid) == warm_worker_pid
        end
        peak_rss_bytes = baseline.fetch(:rss_bytes)
        peak_pss_bytes = baseline.fetch(:pss_bytes)
        control.puts("measure")
        loop do
          current = process_tree_memory(pid)
          peak_rss_bytes = [peak_rss_bytes, current.fetch(:rss_bytes)].max
          peak_pss_bytes = [peak_pss_bytes, current.fetch(:pss_bytes)].max
          break if IO.select([output], nil, nil, memory_poll_seconds)
        end
        raise "Memory phase failed" unless output.gets == "done\n"

        {
          rss_extra_mib: [peak_rss_bytes - baseline.fetch(:rss_bytes), 0].max / 1_048_576.0,
          pss_extra_mib: [peak_pss_bytes - baseline.fetch(:pss_bytes), 0].max / 1_048_576.0,
          worker_idle_rss_mib: worker&.fetch(:rss_bytes)&./(1_048_576.0),
          worker_idle_pss_mib: worker&.fetch(:pss_bytes)&./(1_048_576.0),
        }
      end
    results << row.merge(
      "memory" => memory,
      "median_extra_rss_mib" =>
        memory.map { |sample| sample.fetch(:rss_extra_mib) }.sort.fetch(memory_iterations / 2),
      "median_extra_pss_mib" =>
        memory.map { |sample| sample.fetch(:pss_extra_mib) }.sort.fetch(memory_iterations / 2),
      "warm_worker_pid" => warm_worker_pid,
      "worker_idle_rss_mib" =>
        (
          if backend == :libvips
            memory
              .map { |sample| sample.fetch(:worker_idle_rss_mib) }
              .sort
              .fetch(memory_iterations / 2)
          else
            nil
          end
        ),
      "worker_idle_pss_mib" =>
        (
          if backend == :libvips
            memory
              .map { |sample| sample.fetch(:worker_idle_pss_mib) }
              .sort
              .fetch(memory_iterations / 2)
          else
            nil
          end
        ),
    )
    warn "#{backend}: #{input.fetch(:case_id)} (#{input.fetch(:geometry)}) complete"
    control.puts("next")
  end

  Process.wait(pid)
  raise "Benchmark child failed" unless $CHILD_STATUS.success?

  output.close
  control.close
end

payload = {
  source_head:,
  source_sha256: source_sha256,
  libvips: DiscourseVips.version,
  imagemagick: IO.popen(["magick", "-version"], &:read).lines.first.strip,
  shared_post_processing: "FileHelper.optimize_image!, including pngquant/oxipng/jpegoptim when applicable",
  codec_corpus_commit:,
  strip_image_metadata: SiteSetting.strip_image_metadata,
  iterations:,
  memory_iterations:,
  memory_poll_seconds:,
  ruby: RUBY_DESCRIPTION,
  inputs: inputs.map { |input| input.except(:path) },
  results:,
}
results_directory = output_directory.parent
results_directory.join("results.json").write(JSON.pretty_generate(payload))
DiscourseVips.before_fork
