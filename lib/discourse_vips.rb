# frozen_string_literal: true

require "image_processing/instrumentation"
require "json"
require "rbconfig"
require "tmpdir"

module DiscourseVips
  DEFAULT_TIMEOUT_SECONDS = 30
  private_constant :DEFAULT_TIMEOUT_SECONDS

  WORKER_GRACE_SECONDS = 2
  private_constant :WORKER_GRACE_SECONDS

  DEFAULT_READ_PATHS = %w[/bin /lib /lib64 /usr].freeze
  private_constant :DEFAULT_READ_PATHS

  FONTCONFIG_READ_PATHS = %w[/etc/fonts /var/cache/fontconfig].freeze
  private_constant :FONTCONFIG_READ_PATHS

  # Dynamically loaded libvips modules use this cache to locate their shared libraries.
  DYNAMIC_LINKER_CACHE_PATH = "/etc/ld.so.cache"
  private_constant :DYNAMIC_LINKER_CACHE_PATH

  class Error < RuntimeError
  end

  class WorkerUnavailable < Error
  end
  private_constant :WorkerUnavailable

  class Connection
    def initialize(command:, environment:)
      @pending = {}
      @state_mutex = Mutex.new
      @write_mutex = Mutex.new
      @next_request_id = 0
      start(command, environment)
    end

    def alive?
      @state_mutex.synchronize { @alive }
    end

    def call(request, timeout:)
      response_queue = Queue.new

      @write_mutex.synchronize do
        request_id = register(response_queue)
        @request_writer.write(JSON.generate(request.merge(id: request_id)) << "\n")
      end

      response = response_queue.pop(timeout: timeout + WORKER_GRACE_SECONDS)
      if !response
        remove(request_id)
        close
        raise WorkerUnavailable, "libvips worker did not respond"
      end

      response
    rescue IOError, SystemCallError => error
      remove(request_id) if request_id
      close
      raise WorkerUnavailable, "libvips worker request failed: #{error.message}"
    end

    def close
      @request_writer&.close unless @request_writer&.closed?
      signal_worker("TERM")
      if @response_thread && !@response_thread.join(WORKER_GRACE_SECONDS)
        signal_worker("KILL", group: true)
        @response_thread.join
      end
      fail_pending("libvips worker stopped")
    rescue IOError, Errno::ECHILD
    ensure
      @response_reader&.close unless @response_reader&.closed?
    end

    def discard
      @request_writer&.close unless @request_writer&.closed?
      @response_reader&.close unless @response_reader&.closed?
    rescue IOError
    end

    private

    def start(command, environment)
      request_reader, @request_writer = IO.pipe
      @response_reader, response_writer = IO.pipe
      @request_writer.sync = true

      @worker_pid =
        Process.spawn(
          environment,
          *command,
          3 => request_reader,
          4 => response_writer,
          :in => File::NULL,
          :out => File::NULL,
          :close_others => true,
          :pgroup => true,
          :unsetenv_others => true,
        )
      @alive = true
      @response_thread = Thread.new { read_responses }
    rescue Exception
      @request_writer&.close
      @response_reader&.close
      raise
    ensure
      request_reader&.close
      response_writer&.close
    end

    def register(response_queue)
      @state_mutex.synchronize do
        raise WorkerUnavailable, "libvips worker is unavailable" if !@alive

        @next_request_id += 1
        @pending[@next_request_id] = response_queue
        @next_request_id
      end
    end

    def remove(request_id)
      @state_mutex.synchronize { @pending.delete(request_id) }
    end

    def read_responses
      Thread.current.report_on_exception = false
      while (line = @response_reader.gets)
        response = JSON.parse(line)
        response_queue = remove(response.fetch("id"))
        response_queue&.push(response)
      end
    rescue IOError, SystemCallError, JSON::ParserError, KeyError => error
      fail_pending("libvips worker response failed: #{error.message}")
    ensure
      fail_pending("libvips worker exited")
      @request_writer.close unless @request_writer.closed?
      signal_worker("TERM")
      begin
        Process.waitpid(@worker_pid)
      rescue Errno::ECHILD
      end
      signal_worker("KILL", group: true)
    end

    def signal_worker(signal, group: false)
      Process.kill(signal, group ? -@worker_pid : @worker_pid)
    rescue Errno::ESRCH
    end

    def fail_pending(message)
      pending =
        @state_mutex.synchronize do
          @alive = false
          current = @pending.values
          @pending = {}
          current
        end
      pending.each do |response_queue|
        response_queue.push({ "status" => "unavailable", "message" => message })
      end
    end
  end
  private_constant :Connection

  class << self
    def vips(*command, operation:, read: [], write: [], timeout: nil, nice: 10, failure_message: "")
      timeout ||= DEFAULT_TIMEOUT_SECONDS

      Dir.mktmpdir("discourse-vips-") do |scratch|
        request = {
          command: command.map(&:to_s),
          read: existing_paths([*asset_read_paths, *read]),
          write: existing_paths([scratch, *write]),
          scratch:,
          timeout:,
          nice:,
        }
        execute =
          lambda do
            response = connection.call(request, timeout:)
            return response["value"].to_s if response["status"] == "ok"
            raise Error, "libvips operation timed out" if response["status"] == "timeout"

            message = response["message"].presence || "libvips operation failed"
            raise Error, [failure_message, message].compact_blank.join("\n")
          end

        operation ? ImageProcessing::Instrumentation.instrument(operation:, &execute) : execute.call
      end
    end

    def before_fork
      reset_connection
    end

    private

    def connection
      reset_after_fork if @owner_pid != Process.pid

      @connection_mutex.synchronize do
        @connection = nil if @connection && !@connection.alive?
        @connection ||= Connection.new(command: worker_command, environment: worker_environment)
      end
    rescue SystemCallError => error
      raise WorkerUnavailable, "libvips worker could not start: #{error.message}"
    end

    def reset_after_fork
      @connection&.discard
      @owner_pid = Process.pid
      @connection = nil
      @connection_mutex = Mutex.new
    end

    def reset_connection
      reset_after_fork if @owner_pid != Process.pid
      connection = @connection_mutex.synchronize { @connection.tap { @connection = nil } }
      connection&.close
    end

    def worker_command
      load_paths = [Rails.root.join("lib").to_s]
      %w[ffi json landlock logger ruby-vips].each do |gem_name|
        load_paths.concat(Gem.loaded_specs.fetch(gem_name).full_require_paths)
      end

      [
        RbConfig.ruby,
        "--disable-gems",
        *load_paths.uniq.flat_map { |path| ["-I", path] },
        Rails.root.join("script/discourse_vips_worker").to_s,
        "3",
        "4",
      ]
    end

    def worker_environment
      {
        **ENV.to_h.slice("PATH", "LANG", "LC_ALL"),
        "HOME" => "/tmp",
        "MALLOC_ARENA_MAX" => "2",
        "TMPDIR" => "/tmp",
        "XDG_CACHE_HOME" => "/tmp",
      }
    end

    def asset_read_paths
      @asset_read_paths ||=
        existing_paths([*DEFAULT_READ_PATHS, DYNAMIC_LINKER_CACHE_PATH, *FONTCONFIG_READ_PATHS])
    end

    def existing_paths(paths)
      paths
        .filter { |path| path.to_s != "" && File.exist?(path) }
        .map { |path| File.expand_path(path) }
        .uniq
    end
  end

  @owner_pid = Process.pid
  @connection_mutex = Mutex.new

  at_exit { before_fork if @owner_pid == Process.pid }
end
