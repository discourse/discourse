# frozen_string_literal: true

require "fileutils"
require "image_processing/instrumentation"
require "msgpack"
require "rbconfig"
require "socket"
require "tmpdir"

module DiscourseVips
  DEFAULT_TIMEOUT_SECONDS = 30
  private_constant :DEFAULT_TIMEOUT_SECONDS

  WORKER_GRACE_SECONDS = 2
  private_constant :WORKER_GRACE_SECONDS

  MAX_RESPONSE_BYTES = 8 * 1024
  private_constant :MAX_RESPONSE_BYTES

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
      @state_mutex = Mutex.new
      start(command, environment)
    end

    def alive?
      @state_mutex.synchronize do
        return false if @closed

        Process.waitpid(@worker_pid, Process::WNOHANG).nil?
      rescue Errno::ECHILD
        false
      end
    end

    def call(request, timeout:)
      socket = UNIXSocket.new(@socket_path)
      socket.write(MessagePack.pack(request))
      socket.close_write

      if !IO.select([socket], nil, nil, timeout + WORKER_GRACE_SECONDS)
        close
        raise WorkerUnavailable, "libvips worker did not respond"
      end

      payload = socket.read(MAX_RESPONSE_BYTES + 1).to_s
      raise WorkerUnavailable, "libvips worker returned no response" if payload.empty?
      if payload.bytesize > MAX_RESPONSE_BYTES
        raise WorkerUnavailable, "libvips worker response is too large"
      end

      MessagePack.unpack(payload)
    rescue WorkerUnavailable
      close
      raise
    rescue MessagePack::UnpackError, IOError, SystemCallError => error
      close
      raise WorkerUnavailable, "libvips worker request failed: #{error.message}"
    ensure
      socket&.close unless socket&.closed?
    end

    def close
      worker_pid, owner_writer, socket_directory =
        @state_mutex.synchronize do
          return if @closed

          @closed = true
          [@worker_pid, @owner_writer, @socket_directory]
        end

      owner_writer.close unless owner_writer.closed?
      wait_for_worker(worker_pid)
    rescue IOError, Errno::ECHILD
    ensure
      remove_socket_directory(socket_directory)
    end

    def discard
      @state_mutex.synchronize do
        return if @closed

        @closed = true
        @owner_writer.close unless @owner_writer.closed?
      end
    rescue IOError
    end

    private

    def start(command, environment)
      @socket_directory = Dir.mktmpdir("discourse-vips-worker-")
      @socket_path = File.join(@socket_directory, "socket")
      server = UNIXServer.new(@socket_path)
      owner_reader, @owner_writer = IO.pipe

      @worker_pid =
        Process.spawn(
          environment,
          *command,
          3 => server,
          4 => owner_reader,
          :in => File::NULL,
          :out => File::NULL,
          :close_others => true,
          :pgroup => true,
          :unsetenv_others => true,
        )
      @closed = false
    rescue Exception
      @owner_writer&.close
      remove_socket_directory(@socket_directory)
      raise
    ensure
      server&.close
      owner_reader&.close
    end

    def wait_for_worker(worker_pid)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + WORKER_GRACE_SECONDS
      while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        return if Process.waitpid(worker_pid, Process::WNOHANG)

        sleep 0.01
      end

      Process.kill("KILL", -worker_pid)
      Process.waitpid(worker_pid)
    rescue Errno::ECHILD, Errno::ESRCH
    end

    def remove_socket_directory(directory)
      FileUtils.remove_entry(directory) if directory && File.exist?(directory)
    rescue SystemCallError
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
        if @connection && !@connection.alive?
          @connection.close
          @connection = nil
        end
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
      %w[ffi landlock logger msgpack ruby-vips].each do |gem_name|
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
