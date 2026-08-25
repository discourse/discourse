# frozen_string_literal: true

require "erb"
require "fileutils"
require "image_processing/instrumentation"
require "json"
require "rbconfig"
require "tmpdir"

module DiscourseVips
  VERSION = 1
  DEFAULT_CLIENT_TIMEOUT_SECONDS = 7
  private_constant :DEFAULT_CLIENT_TIMEOUT_SECONDS

  TOPIC_OG_CLIENT_TIMEOUT_SECONDS = 22
  private_constant :TOPIC_OG_CLIENT_TIMEOUT_SECONDS

  # Recycling bounds how long a compromised or leaky worker can live.
  MAX_WORKER_REQUESTS = 500
  private_constant :MAX_WORKER_REQUESTS

  INPUT_NAME = "input"
  private_constant :INPUT_NAME

  OUTPUT_NAME = "output"
  private_constant :OUTPUT_NAME

  INSTRUMENTED_OPERATIONS = {
    "generate_letter_avatar" => :letter_avatar_render,
    "resize_letter_avatar" => :optimized_image_resize,
    "dominant_color" => :upload_dominant_color,
    "svg_to_png" => :topic_og_render,
  }.freeze
  private_constant :INSTRUMENTED_OPERATIONS

  FONT_FAMILIES = {
    "/System/Library/Fonts/Helvetica.ttc" => "Helvetica",
    File.join(DiscourseFonts.path_for_fonts, "NotoSans-Regular.woff2") => "Noto Sans",
  }.freeze
  private_constant :FONT_FAMILIES

  class Error < RuntimeError
  end

  class WorkerFailed < Error
  end
  private_constant :WorkerFailed

  class WorkerTimedOut < Error
  end
  private_constant :WorkerTimedOut

  WorkerHandle = Struct.new(:pid, :stdin, :stdout, :base_dir, :requests)
  private_constant :WorkerHandle

  class << self
    def version
      "#{VERSION}-#{request(operation: "version")}"
    end

    def generate_letter_avatar(letter:, background_color:, font_path:, output_path:)
      font_path = File.expand_path(font_path.to_s)
      font_family = FONT_FAMILIES[font_path]
      if !File.file?(font_path) || !font_family
        raise ArgumentError, "font_path must reference a supported font file"
      end

      request(
        operation: "generate_letter_avatar",
        arguments: {
          markup:
            %(<span foreground="#ffffff" alpha="80%">#{ERB::Util.html_escape(letter.to_s)}</span>),
          font: "#{font_family} 280",
          font_path:,
          background_color: validate_background_color(background_color),
          output: OUTPUT_NAME,
        },
        output_path: File.expand_path(output_path),
      )
      nil
    end

    def resize_letter_avatar(input_path:, output_path:, size:)
      request(
        operation: "resize_letter_avatar",
        arguments: {
          input: INPUT_NAME,
          output: OUTPUT_NAME,
          size:,
        },
        input_path: File.expand_path(input_path),
        output_path: File.expand_path(output_path),
      )
      nil
    end

    def dominant_color(input_path:)
      request(
        operation: "dominant_color",
        arguments: {
          input: INPUT_NAME,
        },
        input_path: File.expand_path(input_path),
      )
    end

    def generate_topic_og_image(svg_path:, output_path:)
      request(
        operation: "svg_to_png",
        arguments: {
          input: INPUT_NAME,
          output: OUTPUT_NAME,
        },
        input_path: File.expand_path(svg_path),
        output_path: File.expand_path(output_path),
        timeout: TOPIC_OG_CLIENT_TIMEOUT_SECONDS,
      )
      nil
    end

    private

    def validate_background_color(background_color)
      channels = Array(background_color)
      if channels.length != 3 ||
           channels.any? { |channel| !channel.is_a?(Integer) || !(0..255).cover?(channel) }
        raise ArgumentError, "background_color must contain three channels in 0..255"
      end
      channels
    end

    def request(
      operation:,
      arguments: {},
      input_path: nil,
      output_path: nil,
      timeout: DEFAULT_CLIENT_TIMEOUT_SECONDS
    )
      instrumentation_operation = INSTRUMENTED_OPERATIONS[operation]
      if !instrumentation_operation
        return request_with_worker(operation:, arguments:, input_path:, output_path:, timeout:)
      end

      ImageProcessing::Instrumentation.instrument(operation: instrumentation_operation) do
        request_with_worker(operation:, arguments:, input_path:, output_path:, timeout:)
      end
    end

    def request_with_worker(operation:, arguments:, input_path:, output_path:, timeout:)
      ensure_sandbox_available!

      lock.synchronize do
        attempts = 0
        begin
          attempts += 1
          current = worker

          begin
            stage_input(current, input_path) if input_path
            response = exchange_request(current, operation:, arguments:, timeout:)
            current.requests += 1

            if response["status"] == "ok"
              collect_output(current, output_path) if output_path
              return response["value"]
            end

            raise Error, response["message"].presence || "libvips operation failed"
          ensure
            clear_exchange(current)
            discard_worker if current.requests >= MAX_WORKER_REQUESTS
          end
        rescue WorkerTimedOut => error
          discard_worker
          raise Error, error.message
        rescue WorkerFailed => error
          discard_worker
          retry if attempts == 1
          raise Error, error.message
        end
      end
    end

    # The worker writes into the exchange directory, so treat its contents as
    # hostile: never follow anything it may have planted there.
    def stage_input(worker, input_path)
      staged = File.join(worker.base_dir, "exchange", INPUT_NAME)
      begin
        File.unlink(staged)
      rescue Errno::ENOENT
      end
      File.open(staged, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
        IO.copy_stream(input_path, file)
      end
    rescue SystemCallError => error
      raise Error, "unable to stage image for libvips: #{error.message}"
    end

    def collect_output(worker, output_path)
      staged = File.join(worker.base_dir, "exchange", OUTPUT_NAME)
      stat =
        begin
          File.lstat(staged)
        rescue Errno::ENOENT
          nil
        end
      raise Error, "libvips operation produced no output" if stat.nil? || !stat.file?

      FileUtils.mv(staged, output_path)
    rescue SystemCallError => error
      raise Error, "unable to collect libvips output: #{error.message}"
    end

    def clear_exchange(worker)
      exchange = File.join(worker.base_dir, "exchange")
      Dir.children(exchange).each { |name| FileUtils.rm_f(File.join(exchange, name)) }
    rescue SystemCallError
    end

    def exchange_request(worker, operation:, arguments:, timeout:)
      worker.stdin.puts(JSON.generate(operation:, arguments:))
      JSON.parse(read_response(worker.stdout, timeout))
    rescue Errno::EPIPE, IOError, SystemCallError => error
      raise WorkerFailed, "libvips worker request failed: #{error.message}"
    rescue JSON::ParserError => error
      raise Error, "libvips worker returned an invalid response: #{error.message}"
    end

    def read_response(io, timeout)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      response = +""

      loop do
        remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        if remaining <= 0 || !IO.select([io], nil, nil, remaining)
          raise WorkerTimedOut, "libvips worker did not respond"
        end

        chunk = io.read_nonblock(65_536, exception: false)
        next if chunk == :wait_readable
        raise WorkerFailed, "libvips worker exited" if chunk.nil?

        response << chunk
        newline = response.index("\n")
        return response.byteslice(0, newline) if newline
      end
    end

    # A forked process inherits the parent's worker pipes; they belong to the
    # parent, so drop them without signalling, waiting, or deleting its files.
    def lock
      if @owner_pid != Process.pid
        stale = @worker
        @worker = nil
        @lock = Mutex.new
        @owner_pid = Process.pid
        close_quietly(stale)
      end
      @lock
    end

    def worker
      @worker ||= spawn_worker
    end

    # The worker boots without rubygems or bundler; resolving its gems here,
    # where the bundle is loaded, keeps it on the locked versions.
    def worker_load_paths
      @worker_load_paths ||=
        %w[ffi ruby-vips landlock discourse-fonts logger].flat_map do |name|
          Gem::Specification.find_by_name(name).full_require_paths
        end
    rescue Gem::LoadError => error
      raise Error, "unable to locate gems for the libvips worker: #{error.message}"
    end

    def spawn_worker
      load_paths = worker_load_paths
      base_dir = Dir.mktmpdir("discourse-vips-")
      FileUtils.mkdir(File.join(base_dir, "exchange"))
      FileUtils.mkdir(File.join(base_dir, "scratch"))

      request_read, request_write = IO.pipe
      response_read, response_write = IO.pipe

      pid =
        Process.spawn(
          { "RUBYOPT" => nil, "MALLOC_ARENA_MAX" => "2" },
          RbConfig.ruby,
          "--disable-gems",
          *load_paths.flat_map { |path| ["-I", path] },
          Rails.root.join("script/discourse_vips_worker").to_s,
          base_dir,
          in: request_read,
          out: response_write,
          close_others: true,
          pgroup: true,
        )

      register_worker_cleanup
      request_write.sync = true
      WorkerHandle.new(pid, request_write, response_read, base_dir, 0)
    ensure
      request_read&.close
      response_write&.close
    end

    def register_worker_cleanup
      return if @cleanup_pid == Process.pid

      @cleanup_pid = Process.pid
      owner = Process.pid
      at_exit { discard_worker if Process.pid == owner && @owner_pid == owner }
    end

    def discard_worker
      worker = @worker
      @worker = nil
      return if !worker

      begin
        Process.kill("TERM", worker.pid)
      rescue Errno::ESRCH
      end
      close_quietly(worker)
      begin
        Process.waitpid(worker.pid)
      rescue Errno::ECHILD
      end
      begin
        FileUtils.remove_entry(worker.base_dir)
      rescue SystemCallError
      end
    end

    def close_quietly(worker)
      return if !worker

      [worker.stdin, worker.stdout].each do |io|
        io.close if !io.closed?
      rescue IOError
      end
    end

    def ensure_sandbox_available!
      if !Rails.env.local? && !Discourse::SafeExec.landlock_supported?
        raise Error, "Cannot run libvips because Landlock sandboxing is unavailable"
      end
    end
  end
end
