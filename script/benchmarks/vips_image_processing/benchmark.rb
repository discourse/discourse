# frozen_string_literal: true

require "chunky_png"
require "digest"
require "fileutils"
require "json"
require "open3"
require "time"

BenchmarkConfig =
  Data.define(
    :results_dir,
    :timing_samples,
    :rss_samples,
    :warmups,
    :seed,
    :source_revision,
    :runtime_image_id,
    :benchmark_image_id,
    :docker_revision,
  )

BenchmarkOperation =
  Data.define(
    :key,
    :label,
    :input,
    :output_extension,
    :type,
    :expected,
    :mean_error_limit,
    :size_ratio,
    :expected_format,
    :expected_orientation,
    :metadata_stripped,
  )

class ProcessTreeMonitor
  attr_reader :peak_rss_kb

  def initialize(root_pid)
    @root_pid = root_pid
    @peak_rss_kb = 0
    @running = false
  end

  def start
    @running = true
    ready = Queue.new
    @thread =
      Thread.new do
        first_scan = true
        loop do
          @peak_rss_kb = [@peak_rss_kb, process_tree_rss_kb].max
          if first_scan
            ready << true
            first_scan = false
          end
          break if !@running
          sleep 0.001
        end
      end
    ready.pop
  end

  def stop
    @running = false
    @thread.join
  end

  private

  def process_tree_rss_kb
    processes =
      Dir
        .glob("/proc/[0-9]*/stat")
        .filter_map do |path|
          stat = File.read(path)
          close = stat.rindex(")")
          fields = stat.byteslice((close + 2)..).split
          [File.basename(File.dirname(path)).to_i, fields.fetch(1).to_i]
        rescue Errno::ENOENT, Errno::EACCES, Errno::ESRCH, IndexError
          nil
        end

    descendants = Set.new([@root_pid])
    loop do
      previous_size = descendants.size
      processes.each { |pid, parent| descendants << pid if descendants.include?(parent) }
      break if descendants.size == previous_size
    end

    descendants.sum do |pid|
      status = File.read("/proc/#{pid}/status")
      status[/^VmRSS:\s+(\d+)\s+kB$/, 1].to_i
    rescue Errno::ENOENT, Errno::EACCES, Errno::ESRCH
      0
    end
  end
end

class VipsImageProcessingBenchmark
  CANDIDATES = %w[image_magick vips].freeze
  SOURCE_FILES = %w[
    app/models/optimized_image.rb
    app/models/upload.rb
    config/imagemagick/policy.xml
    config/initializers/000-zeitwerk.rb
    config/site_settings.yml
    Gemfile.lock
    lib/discourse/safe_exec.rb
    lib/file_helper.rb
    lib/freedom_patches/image_optim_sandbox.rb
    lib/image_magick.rb
    lib/upload_creator.rb
    lib/vips.rb
    lib/vips/ico.rb
    lib/vips/image_processor.rb
    lib/vips/jpeg_quality.rb
    script/benchmarks/vips_image_processing/benchmark.rb
    vendor/data/RT_sRGB.icm
  ].freeze

  def initialize(config)
    @config = config
    @random = Random.new(config.seed)
    @samples_path = File.join(config.results_dir, "samples.jsonl")
    @correctness_path = File.join(config.results_dir, "correctness.json")
    @analysis_path = File.join(config.results_dir, "analysis.json")
    @summary_path = File.join(config.results_dir, "summary.md")
    @sample_sequence = 0
    @references = {}
    @operations = operations
  end

  def run
    preflight
    FileUtils.mkdir_p(@config.results_dir)
    File.write(@samples_path, "")
    prepare_inputs
    initialize_shared_production_state
    write_environment

    Dir.mktmpdir("vips-image-processing-", @config.results_dir) do |work_root|
      @work_root = work_root
      verify_correctness
      run_warmups
      run_samples(mode: "timing", count: @config.timing_samples)
      run_rss_baseline
      run_samples(mode: "rss", count: @config.rss_samples)
    end

    write_analysis
    write_run_state
    write_checksums
  end

  private

  def operations
    [
      BenchmarkOperation.new(
        key: "optimized_resize",
        label: "Optimized resize (photograph)",
        input: "photograph.jpg",
        output_extension: ".jpg",
        type: "image",
        expected: [512, 384],
        mean_error_limit: 0.03,
        size_ratio: (0.5..2.0),
        expected_format: :jpeg,
        expected_orientation: nil,
        metadata_stripped: true,
      ),
      BenchmarkOperation.new(
        key: "optimized_north_crop",
        label: "Optimized north crop (high detail)",
        input: "high-detail.png",
        output_extension: ".png",
        type: "image",
        expected: [640, 640],
        mean_error_limit: 0.03,
        size_ratio: (0.5..2.0),
        expected_format: :png,
        expected_orientation: nil,
        metadata_stripped: true,
      ),
      BenchmarkOperation.new(
        key: "optimized_downsize",
        label: "Optimized downsize (8900×8900)",
        input: "large.jpg",
        output_extension: ".jpg",
        type: "image",
        expected: [1600, 1600],
        mean_error_limit: 0.03,
        size_ratio: (0.5..2.0),
        expected_format: :jpeg,
        expected_orientation: nil,
        metadata_stripped: true,
      ),
      BenchmarkOperation.new(
        key: "png_to_jpeg",
        label: "PNG-to-JPEG conversion",
        input: "transparent.png",
        output_extension: ".jpg",
        type: "image",
        expected: [2032, 1312],
        mean_error_limit: 0.03,
        size_ratio: (0.5..2.0),
        expected_format: :jpeg,
        expected_orientation: nil,
        metadata_stripped: nil,
      ),
      BenchmarkOperation.new(
        key: "heic_to_jpeg",
        label: "HEIC-to-JPEG conversion",
        input: "input.heic",
        output_extension: ".jpg",
        type: "image",
        expected: [846, 1129],
        mean_error_limit: 0.03,
        size_ratio: (0.5..2.0),
        expected_format: :jpeg,
        expected_orientation: 1,
        metadata_stripped: nil,
      ),
      BenchmarkOperation.new(
        key: "orientation_correction",
        label: "EXIF orientation correction",
        input: "oriented.jpg",
        output_extension: ".jpg",
        type: "image",
        expected: [1312, 2032],
        mean_error_limit: 0.1,
        size_ratio: (0.5..2.0),
        expected_format: :jpeg,
        expected_orientation: 1,
        metadata_stripped: nil,
      ),
      BenchmarkOperation.new(
        key: "svg_dimensions",
        label: "SVG dimension probe",
        input: "massive.svg",
        output_extension: ".json",
        type: "scalar",
        expected: [11_520, 11_615],
        mean_error_limit: nil,
        size_ratio: nil,
        expected_format: nil,
        expected_orientation: nil,
        metadata_stripped: nil,
      ),
      BenchmarkOperation.new(
        key: "animated_frame_count",
        label: "Animated WebP fallback probe",
        input: "animated.webp",
        output_extension: ".json",
        type: "scalar",
        expected: true,
        mean_error_limit: nil,
        size_ratio: nil,
        expected_format: nil,
        expected_orientation: nil,
        metadata_stripped: nil,
      ),
      BenchmarkOperation.new(
        key: "jpeg_quality",
        label: "JPEG source-quality probe",
        input: "photograph.jpg",
        output_extension: ".json",
        type: "scalar",
        expected: 85,
        mean_error_limit: nil,
        size_ratio: nil,
        expected_format: nil,
        expected_orientation: nil,
        metadata_stripped: nil,
      ),
      BenchmarkOperation.new(
        key: "ico_conversion",
        label: "ICO-to-PNG conversion",
        input: "input.ico",
        output_extension: ".png",
        type: "image",
        expected: [1, 1],
        mean_error_limit: 0.0,
        size_ratio: nil,
        expected_format: :png,
        expected_orientation: nil,
        metadata_stripped: nil,
      ),
    ]
  end

  def preflight
    raise "benchmark must run on Linux with /proc mounted" if !Dir.exist?("/proc")
    raise "benchmark must run as an unprivileged user" if Process.uid.zero?
    raise "VIPS_CONCURRENCY must remain unset" if ENV.key?("VIPS_CONCURRENCY")
    if Dir.exist?(@config.results_dir) && !Dir.children(@config.results_dir).empty?
      raise "results directory is not empty"
    end
    raise "source revision must be a full Git revision" if !full_revision?(@config.source_revision)
    raise "runtime image ID is required" if @config.runtime_image_id.empty?
    raise "benchmark image ID is required" if @config.benchmark_image_id.empty?
    raise "Docker revision must be a full Git revision" if !full_revision?(@config.docker_revision)
    raise "Landlock is unavailable" if !Discourse::SafeExec.landlock_supported?

    @actual_source_revision = git_output("rev-parse", "HEAD").strip
    if @actual_source_revision != @config.source_revision
      raise(
        "source revision mismatch: #{@config.source_revision} requested, " \
          "#{@actual_source_revision} checked out",
      )
    end
    @source_worktree_status = git_output("status", "--porcelain=v1", "--untracked-files=all")
    if @source_worktree_status.present?
      raise "source worktree is dirty:\n#{@source_worktree_status}"
    end

    %w[vips vipsheader magick].each do |executable|
      available =
        ENV
          .fetch("PATH")
          .split(File::PATH_SEPARATOR)
          .any? { |directory| File.executable?(File.join(directory, executable)) }
      raise "#{executable} is unavailable" if !available
    end
  end

  def prepare_inputs
    @inputs_dir = File.join(@config.results_dir, "correctness", "inputs")
    FileUtils.mkdir_p(@inputs_dir)
    sources = {
      "photograph.jpg" =>
        Rails.root.join("plugins/styleguide/public/images/hubble-orion-nebula-bg.jpg"),
      "high-detail.png" => Rails.root.join("spec/fixtures/images/large_and_unoptimized.png"),
      "large.jpg" => Rails.root.join("spec/fixtures/images/huge.jpg"),
      "input.heic" => Rails.root.join("spec/fixtures/images/should_be_jpeg.heic"),
      "massive.svg" => Rails.root.join("spec/fixtures/images/massive.svg"),
      "animated.webp" => Rails.root.join("spec/fixtures/images/animated.webp"),
      "input.ico" => Rails.root.join("spec/fixtures/images/smallest.ico"),
    }
    sources.each { |name, path| FileUtils.cp(path, File.join(@inputs_dir, name)) }

    transparent = File.join(@inputs_dir, "transparent.png")
    Vips.call(
      "copy",
      File.join(@inputs_dir, "high-detail.png"),
      "#{transparent}[compression=0]",
      read: [File.join(@inputs_dir, "high-detail.png")],
      write: [@inputs_dir],
    )

    oriented = File.join(@inputs_dir, "oriented.jpg")
    source = File.join(@inputs_dir, "high-detail.png")
    Vips.call("copy", source, "#{oriented}[Q=82,strip=true]", read: [source], write: [@inputs_dir])
    inject_orientation(path: oriented, orientation: 6)
  end

  def initialize_shared_production_state
    [false, true].each do |allow_pngquant|
      FileHelper.image_optim(
        allow_pngquant:,
        strip_image_metadata: SiteSetting.strip_image_metadata,
      )
    end
  end

  def inject_orientation(path:, orientation:)
    jpeg = File.binread(path)
    tiff =
      "II".b + [42].pack("v") + [8].pack("V") + [1].pack("v") + [0x0112, 3].pack("v2") +
        [1].pack("V") + [orientation, 0].pack("v2") + [0].pack("V")
    payload = "Exif\0\0".b + tiff
    segment = "\xFF\xE1".b + [payload.bytesize + 2].pack("n") + payload
    File.binwrite(path, jpeg.byteslice(0, 2) + segment + jpeg.byteslice(2..))
  end

  def verify_correctness
    correctness = {}

    @operations.each do |operation|
      reference = run_correctness(operation:, candidate: "image_magick")
      @references[operation.key] = reference
      image_magick_parity = validate(operation:, output: reference.fetch(:output), reference:)
      vips = run_correctness(operation:, candidate: "vips")
      vips_parity = validate(operation:, output: vips.fetch(:output), reference:)

      correctness[operation.key] = {
        label: operation.label,
        expected: operation.expected,
        image_magick: correctness_record(reference, image_magick_parity),
        vips: correctness_record(vips, vips_parity),
      }
    end

    File.write(@correctness_path, JSON.pretty_generate(correctness) + "\n")
  end

  def run_correctness(operation:, candidate:)
    directory = File.join(@config.results_dir, "correctness", "#{operation.key}-#{candidate}")
    FileUtils.mkdir_p(directory)
    output = File.join(directory, "output#{operation.output_extension}")
    measurement =
      measure(operation:, candidate:, mode: "correctness", sequence: 0, output:, preserve: true)
    measurement.merge(output:)
  end

  def correctness_record(measurement, parity)
    {
      elapsed_ms: measurement.fetch(:elapsed_ms),
      output_sha256: Digest::SHA256.file(measurement.fetch(:output)).hexdigest,
      output_bytes: File.size(measurement.fetch(:output)),
      parity:,
    }
  end

  def run_warmups
    jobs =
      @operations.flat_map do |operation|
        CANDIDATES.flat_map { |candidate| @config.warmups.times.map { [operation, candidate] } }
      end

    jobs
      .shuffle(random: @random)
      .each_with_index do |(operation, candidate), index|
        measure(
          operation:,
          candidate:,
          mode: "warmup",
          sequence: index + 1,
          output: nil,
          preserve: false,
        )
      end
  end

  def run_samples(mode:, count:)
    jobs =
      @operations.flat_map do |operation|
        CANDIDATES.flat_map { |candidate| count.times.map { [operation, candidate] } }
      end

    jobs
      .shuffle(random: @random)
      .each do |operation, candidate|
        @sample_sequence += 1
        measurement =
          measure(
            operation:,
            candidate:,
            mode:,
            sequence: @sample_sequence,
            output: nil,
            preserve: false,
          )
        parity =
          validate(
            operation:,
            output: measurement.fetch(:output),
            reference: @references.fetch(operation.key),
          )
        record = {
          sequence: @sample_sequence,
          mode:,
          operation: operation.key,
          operation_label: operation.label,
          candidate:,
          elapsed_ms: measurement.fetch(:elapsed_ms),
          peak_rss_kb: measurement[:peak_rss_kb],
          output_sha256: Digest::SHA256.file(measurement.fetch(:output)).hexdigest,
          output_bytes: File.size(measurement.fetch(:output)),
          parity:,
          qualified: true,
        }
        File.open(@samples_path, "a") { |file| file.puts(JSON.generate(record)) }
        FileUtils.rm_rf(measurement.fetch(:directory))
      end
  end

  def run_rss_baseline
    samples = Array.new(@config.rss_samples) { measure_rss_baseline }
    File.write(
      File.join(@config.results_dir, "rss-baseline.json"),
      JSON.pretty_generate(
        {
          sample_count: samples.length,
          samples_kb: samples,
          p50_kb: median(samples),
          maximum_observed_peak_rss_kb: samples.max,
          definition:
            "forked Rails child at the same ready/start barrier without an image operation or child CLI",
        },
      ) + "\n",
    )
  end

  def measure_rss_baseline
    ready_reader, ready_writer = IO.pipe
    start_reader, start_writer = IO.pipe
    pid =
      fork do
        ready_reader.close
        start_writer.close
        GC.start
        ready_writer.write("1")
        ready_writer.close
        start_reader.read(1)
        start_reader.close
        exit! 0
      end

    ready_writer.close
    start_reader.close
    ready_reader.read(1)
    ready_reader.close
    monitor = ProcessTreeMonitor.new(pid)
    monitor.start
    start_writer.write("1")
    start_writer.close
    Process.wait(pid)
    monitor.stop
    monitor.peak_rss_kb
  end

  def measure(operation:, candidate:, mode:, sequence:, output:, preserve:)
    directory =
      if preserve
        File.dirname(output)
      else
        Dir.mktmpdir("#{operation.key}-#{candidate}-", @work_root)
      end
    input = File.join(directory, operation.input)
    FileUtils.cp(File.join(@inputs_dir, operation.input), input)
    output ||= File.join(directory, "output#{operation.output_extension}")

    ready_reader, ready_writer = IO.pipe
    start_reader, start_writer = IO.pipe
    result_reader, result_writer = IO.pipe
    pid =
      fork do
        ready_reader.close
        start_writer.close
        result_reader.close
        begin
          set_candidate(candidate)
          context = prepare_operation(operation:, input:)
          GC.start
          ready_writer.write("1")
          ready_writer.close
          start_reader.read(1)
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = execute_operation(operation:, input:, output:, context:)
          elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
          materialize_result(operation:, output:, result:)
          result_writer.write(JSON.generate({ elapsed_ms: }))
          result_writer.close
          exit! 0
        rescue Exception => error
          result_writer.write(
            JSON.generate(
              { error: error.full_message(highlight: false, order: :top), class: error.class.name },
            ),
          )
          result_writer.close
          exit! 1
        end
      end

    ready_writer.close
    start_reader.close
    result_writer.close
    ready_reader.read(1)
    ready_reader.close
    monitor = ProcessTreeMonitor.new(pid) if mode == "rss"
    monitor&.start
    start_writer.write("1")
    start_writer.close
    _finished_pid, status = Process.wait2(pid)
    monitor&.stop
    payload = JSON.parse(result_reader.read, symbolize_names: true)
    result_reader.close
    raise payload.fetch(:error, "sample child failed") if !status.success?
    raise "sample did not create #{output}" if !File.file?(output)

    {
      directory:,
      output:,
      elapsed_ms: payload.fetch(:elapsed_ms),
      peak_rss_kb: monitor&.peak_rss_kb,
      mode:,
      sequence:,
    }
  end

  def set_candidate(candidate)
    enabled = candidate == "vips"
    SiteSetting.singleton_class.send(:define_method, :use_vips_for_image_processing) { enabled }
  end

  def prepare_operation(operation:, input:)
    case operation.key
    when "optimized_resize", "optimized_north_crop"
      Upload.new.target_image_quality(input, SiteSetting.ImageQuality.image_preview_jpg_quality)
    when "png_to_jpeg", "heic_to_jpeg", "orientation_correction", "ico_conversion"
      file = File.open(input, "r+b")
      creator = UploadCreator.new(file, File.basename(input), force_optimize: true)
      creator.extract_image_info!
      creator
    when "animated_frame_count"
      file = File.open(input, "rb")
      creator = UploadCreator.new(file, File.basename(input), force_optimize: true)
      creator.extract_image_info!
      FastImage.singleton_class.send(:define_method, :animated?) { |_file| nil }
      creator
    when "jpeg_quality"
      Upload.new
    end
  end

  def execute_operation(operation:, input:, output:, context:)
    case operation.key
    when "optimized_resize"
      OptimizedImage.resize(input, output, 512, 384, quality: context, raise_on_error: true)
      output
    when "optimized_north_crop"
      OptimizedImage.crop(input, output, 640, 640, quality: context, raise_on_error: true)
      output
    when "optimized_downsize"
      OptimizedImage.downsize(input, output, "1600x1600>", raise_on_error: true)
      output
    when "png_to_jpeg"
      if !context.convert_png_to_jpeg?
        raise "PNG fixture does not qualify for production conversion"
      end
      context.convert_to_jpeg!
      context.instance_variable_get(:@file).path
    when "heic_to_jpeg"
      context.convert_heif!
      context.instance_variable_get(:@file).path
    when "orientation_correction"
      context.fix_orientation!
      context.instance_variable_get(:@file).path
    when "svg_dimensions"
      if SiteSetting.use_vips_for_image_processing
        Vips.dimensions(input, format: "svg")
      else
        ImageMagick
          .identify(
            "-ping",
            "-format",
            "%w %h",
            "MSVG:#{input}",
            read: [input],
            timeout: Upload::MAX_IDENTIFY_SECONDS,
          )
          .split
          .map(&:to_i)
      end
    when "animated_frame_count"
      context.send(:animated?)
    when "jpeg_quality"
      context.target_image_quality(input, 85)
    when "ico_conversion"
      context.convert_favicon_to_png!
      context.instance_variable_get(:@file).path
    end
  end

  def materialize_result(operation:, output:, result:)
    if operation.type == "scalar"
      File.write(output, JSON.generate(result))
    elsif result != output
      FileUtils.cp(result, output)
    end
  end

  def validate(operation:, output:, reference:)
    if operation.type == "scalar"
      actual = JSON.parse(File.read(output))
      expected = operation.expected
      if actual != expected
        raise "#{operation.key} returned #{actual.inspect}, expected #{expected.inspect}"
      end
      reference_value = JSON.parse(File.read(reference.fetch(:output)))
      raise "#{operation.key} differs from ImageMagick" if actual != reference_value
      return { value: actual, exact_match: true }
    end

    dimensions = FastImage.size(output)
    raise "#{operation.key} dimensions #{dimensions.inspect}" if dimensions != operation.expected
    reference_dimensions = FastImage.size(reference.fetch(:output))
    raise "#{operation.key} reference dimensions differ" if dimensions != reference_dimensions
    encoded_format = FastImage.type(output)
    if encoded_format != operation.expected_format
      raise(
        "#{operation.key} encoded format #{encoded_format.inspect}, " \
          "expected #{operation.expected_format.inspect}",
      )
    end

    orientation = image_orientation(output)
    if operation.expected_orientation && orientation != operation.expected_orientation
      raise(
        "#{operation.key} orientation #{orientation.inspect}, " \
          "expected #{operation.expected_orientation}",
      )
    end
    metadata = metadata_presence(output)
    reference_metadata = metadata_presence(reference.fetch(:output))
    if metadata.fetch(:icc_profile) != reference_metadata.fetch(:icc_profile)
      raise "#{operation.key} ICC profile presence differs from ImageMagick"
    end
    if operation.metadata_stripped && metadata.fetch(:xmp)
      raise "#{operation.key} retained XMP metadata"
    end

    mean_error = normalized_mean_error(reference.fetch(:output), output)
    if mean_error > operation.mean_error_limit
      raise "#{operation.key} normalized mean error #{mean_error} exceeds #{operation.mean_error_limit}"
    end

    size_ratio = File.size(output).fdiv(File.size(reference.fetch(:output)))
    if operation.size_ratio && !operation.size_ratio.cover?(size_ratio)
      raise "#{operation.key} size ratio #{size_ratio} is outside #{operation.size_ratio}"
    end

    {
      dimensions:,
      encoded_format:,
      orientation:,
      metadata:,
      rgba_parity_including_alpha: true,
      normalized_mean_rgba_error: mean_error,
      file_size_ratio_vs_image_magick: size_ratio,
    }
  end

  def image_orientation(path)
    Vips.header(path, field: "orientation").to_i
  rescue Discourse::Utils::CommandError
    nil
  end

  def metadata_presence(path)
    { xmp: image_header?(path, "xmp-data"), icc_profile: image_header?(path, "icc-profile-data") }
  end

  def image_header?(path, field)
    Vips.header(path, field:).present?
  rescue Discourse::Utils::CommandError
    false
  end

  def normalized_mean_error(reference, candidate)
    Dir.mktmpdir("vips-parity-", @work_root) do |directory|
      reference_png = File.join(directory, "reference.png")
      candidate_png = File.join(directory, "candidate.png")
      normalize_image(reference, reference_png)
      normalize_image(candidate, candidate_png)
      reference_image = ChunkyPNG::Image.from_file(reference_png)
      candidate_image = ChunkyPNG::Image.from_file(candidate_png)
      reference_dimensions = [reference_image.width, reference_image.height]
      candidate_dimensions = [candidate_image.width, candidate_image.height]
      raise "normalized dimensions differ" if reference_dimensions != candidate_dimensions

      channel_error = 0
      reference_image
        .pixels
        .zip(candidate_image.pixels) do |left, right|
          channel_error += (ChunkyPNG::Color.r(left) - ChunkyPNG::Color.r(right)).abs
          channel_error += (ChunkyPNG::Color.g(left) - ChunkyPNG::Color.g(right)).abs
          channel_error += (ChunkyPNG::Color.b(left) - ChunkyPNG::Color.b(right)).abs
          channel_error += (ChunkyPNG::Color.a(left) - ChunkyPNG::Color.a(right)).abs
        end
      channel_error.fdiv(reference_image.pixels.length * 4 * 255)
    end
  end

  def normalize_image(input, output)
    ImageMagick.magick(
      input,
      "-alpha",
      "on",
      "-depth",
      "8",
      "-define",
      "png:color-type=6",
      output,
      read: [input],
      write: [File.dirname(output)],
      timeout: 20,
    )
  end

  def write_environment
    environment = {
      generated_at: Time.now.utc.iso8601,
      source_revision: @config.source_revision,
      verified_source_revision: @actual_source_revision,
      source_worktree_status: @source_worktree_status,
      docker_revision: @config.docker_revision,
      runtime_image_id: @config.runtime_image_id,
      benchmark_image_id: @config.benchmark_image_id,
      ruby: RUBY_DESCRIPTION,
      rails_environment: Rails.env,
      uid: Process.uid,
      gid: Process.gid,
      platform: RUBY_PLATFORM,
      uname: command_output("uname", "-a"),
      cpu: command_output("lscpu"),
      memory: File.read("/proc/meminfo"),
      vips_version: command_output("vips", "--version"),
      image_magick_version: command_output("magick", "--version"),
      package_versions: command_output("dpkg-query", "-W"),
      binaries: binary_evidence,
      settings: {
        strip_image_metadata: SiteSetting.strip_image_metadata,
        image_preview_jpg_quality: SiteSetting.ImageQuality.image_preview_jpg_quality,
        vip_concurrency_present: ENV.key?("VIPS_CONCURRENCY"),
      },
      benchmark: {
        timing_samples_per_cell: @config.timing_samples,
        rss_samples_per_cell: @config.rss_samples,
        warmups_per_cell: @config.warmups,
        seed: @config.seed,
        concurrency: "library defaults; no VIPS_CONCURRENCY",
        rss_definition:
          "maximum observed sum of VmRSS for the forked Rails operation process and all descendants",
      },
      source_sha256: source_hashes,
      input_sha256: input_hashes,
    }
    File.write(
      File.join(@config.results_dir, "environment.json"),
      JSON.pretty_generate(environment) + "\n",
    )
  end

  def source_hashes
    SOURCE_FILES.to_h do |relative_path|
      path = Rails.root.join(relative_path)
      [relative_path, Digest::SHA256.file(path).hexdigest]
    end
  end

  def input_hashes
    Dir
      .children(@inputs_dir)
      .sort
      .to_h { |name| [name, Digest::SHA256.file(File.join(@inputs_dir, name)).hexdigest] }
  end

  def command_output(*command)
    stdout, stderr, status = Open3.capture3(*command)
    raise "#{command.join(" ")} failed:\n#{stderr}" if !status.success?
    stdout
  end

  def git_output(*arguments)
    command_output("git", "-c", "safe.directory=#{Rails.root}", *arguments)
  end

  def full_revision?(value)
    value.match?(/\A[0-9a-f]{40}\z/)
  end

  def binary_evidence
    %w[vips vipsheader magick].to_h do |executable|
      path = command_output("which", executable).strip
      [executable, { path:, sha256: Digest::SHA256.file(path).hexdigest }]
    end
  end

  def write_analysis
    samples = File.readlines(@samples_path, chomp: true).map { |line| JSON.parse(line) }
    analysis = {}

    @operations.each do |operation|
      candidate_analysis = {}
      CANDIDATES.each do |candidate|
        timing =
          samples.filter do |sample|
            sample["operation"] == operation.key && sample["candidate"] == candidate &&
              sample["mode"] == "timing"
          end
        rss =
          samples.filter do |sample|
            sample["operation"] == operation.key && sample["candidate"] == candidate &&
              sample["mode"] == "rss"
          end
        candidate_analysis[candidate] = {
          timing_sample_count: timing.length,
          rss_sample_count: rss.length,
          p50_ms: median(timing.map { |sample| sample.fetch("elapsed_ms") }),
          maximum_observed_peak_rss_kb: rss.map { |sample| sample.fetch("peak_rss_kb") }.max,
        }
      end

      image_magick = candidate_analysis.fetch("image_magick")
      vips = candidate_analysis.fetch("vips")
      vips[:time_difference_ms_vs_image_magick] = vips.fetch(:p50_ms) - image_magick.fetch(:p50_ms)
      vips[:time_difference_percent_vs_image_magick] = percent_difference(
        vips.fetch(:p50_ms),
        image_magick.fetch(:p50_ms),
      )
      vips[:memory_difference_kb_vs_image_magick] = vips.fetch(:maximum_observed_peak_rss_kb) -
        image_magick.fetch(:maximum_observed_peak_rss_kb)
      vips[:memory_difference_percent_vs_image_magick] = percent_difference(
        vips.fetch(:maximum_observed_peak_rss_kb),
        image_magick.fetch(:maximum_observed_peak_rss_kb),
      )
      analysis[operation.key] = { label: operation.label, candidates: candidate_analysis }
    end

    File.write(@analysis_path, JSON.pretty_generate(analysis) + "\n")
    write_summary(analysis)
  end

  def median(values)
    sorted = values.sort
    middle = sorted.length / 2
    if sorted.length.odd?
      sorted.fetch(middle)
    else
      (sorted.fetch(middle - 1) + sorted.fetch(middle)) / 2
    end
  end

  def percent_difference(value, baseline)
    (value - baseline).fdiv(baseline) * 100
  end

  def write_summary(analysis)
    lines = [
      "# Stock vips production-path benchmark",
      "",
      "| Operation | Method | p50 time | Maximum peak RSS | Time difference vs IM | Memory difference vs IM |",
      "| --- | --- | ---: | ---: | ---: | ---: |",
    ]

    analysis.each_value do |operation|
      image_magick = operation.fetch(:candidates).fetch("image_magick")
      vips = operation.fetch(:candidates).fetch("vips")
      lines << summary_row(operation.fetch(:label), "ImageMagick", image_magick)
      lines << summary_row(operation.fetch(:label), "VIPS-enabled production path", vips)
    end

    regressions =
      analysis.values.filter_map do |operation|
        vips = operation.fetch(:candidates).fetch("vips")
        if vips.fetch(:time_difference_ms_vs_image_magick) > 5 &&
             vips.fetch(:time_difference_percent_vs_image_magick) > 10
          {
            operation: operation.fetch(:label),
            time_difference_ms: vips.fetch(:time_difference_ms_vs_image_magick),
            time_difference_percent: vips.fetch(:time_difference_percent_vs_image_magick),
          }
        end
      end

    lines.concat(
      [
        "",
        "Times use only the dedicated timing samples. RSS is the maximum observed process-tree peak across the dedicated RSS samples; it is not a mean of per-run peaks. Both engines use their defaults and `VIPS_CONCURRENCY` is absent.",
        "",
        rss_baseline_summary,
        "",
        "Every recorded sample passed the operation-specific semantic and visual comparison against the preserved ImageMagick reference output.",
        "",
        "## Material time regressions",
        "",
      ],
    )
    if regressions.empty?
      lines << "None met the investigation threshold of both 5 ms and 10% slower than ImageMagick."
    else
      regressions.each do |regression|
        lines << format(
          "- %s: %+.2f ms (%+.1f%%)",
          regression.fetch(:operation),
          regression.fetch(:time_difference_ms),
          regression.fetch(:time_difference_percent),
        )
      end
    end

    lines.concat(
      [
        "",
        "The raw samples, exact environment, source and fixture hashes, correctness outputs, and machine-readable analysis are stored beside this summary.",
        "",
      ],
    )
    File.write(@summary_path, lines.join("\n"))
  end

  def summary_row(label, method, values)
    if method == "ImageMagick"
      time_difference = "—"
      memory_difference = "—"
    else
      time_difference =
        format(
          "%+.2f ms (%+.1f%%)",
          values.fetch(:time_difference_ms_vs_image_magick),
          values.fetch(:time_difference_percent_vs_image_magick),
        )
      memory_difference =
        format(
          "%+.2f MiB (%+.1f%%)",
          values.fetch(:memory_difference_kb_vs_image_magick) / 1024.0,
          values.fetch(:memory_difference_percent_vs_image_magick),
        )
    end

    format(
      "| %s | %s | %.2f ms | %.2f MiB | %s | %s |",
      label,
      method,
      values.fetch(:p50_ms),
      values.fetch(:maximum_observed_peak_rss_kb) / 1024.0,
      time_difference,
      memory_difference,
    )
  end

  def rss_baseline_summary
    baseline =
      JSON.parse(
        File.read(File.join(@config.results_dir, "rss-baseline.json")),
        symbolize_names: true,
      )
    format(
      "The no-operation fork baseline was %.2f MiB p50 and %.2f MiB maximum. Small RSS differences near that baseline should not be attributed to an image engine.",
      baseline.fetch(:p50_kb) / 1024.0,
      baseline.fetch(:maximum_observed_peak_rss_kb) / 1024.0,
    )
  end

  def write_checksums
    files =
      Dir
        .glob(File.join(@config.results_dir, "**", "*"))
        .select { |path| File.file?(path) }
        .reject { |path| File.basename(path) == "artifacts.sha256" }
        .sort
    lines =
      files.map do |path|
        relative = path.delete_prefix("#{@config.results_dir}/")
        "#{Digest::SHA256.file(path).hexdigest}  #{relative}"
      end
    File.write(File.join(@config.results_dir, "artifacts.sha256"), lines.join("\n") + "\n")
  end

  def write_run_state
    sample_count = File.foreach(@samples_path).count
    File.write(
      File.join(@config.results_dir, "run-state.json"),
      JSON.pretty_generate(
        {
          completed: true,
          completed_at: Time.now.utc.iso8601,
          source_revision: @config.source_revision,
          sample_count:,
          expected_sample_count:
            @operations.length * CANDIDATES.length * (@config.timing_samples + @config.rss_samples),
        },
      ) + "\n",
    )
  end
end

config =
  BenchmarkConfig.new(
    results_dir: File.expand_path(ENV.fetch("VIPS_BENCH_RESULTS_DIR")),
    timing_samples: Integer(ENV.fetch("VIPS_BENCH_TIMING_SAMPLES", "15")),
    rss_samples: Integer(ENV.fetch("VIPS_BENCH_RSS_SAMPLES", "5")),
    warmups: Integer(ENV.fetch("VIPS_BENCH_WARMUPS", "3")),
    seed: Integer(ENV.fetch("VIPS_BENCH_SEED", "20260730")),
    source_revision: ENV.fetch("BENCHMARK_SOURCE_REVISION"),
    runtime_image_id: ENV.fetch("BENCHMARK_RUNTIME_IMAGE_ID"),
    benchmark_image_id: ENV.fetch("BENCHMARK_IMAGE_ID"),
    docker_revision: ENV.fetch("BENCHMARK_DOCKER_REVISION"),
  )

VipsImageProcessingBenchmark.new(config).run
