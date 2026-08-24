# frozen_string_literal: true

require "fileutils"
require "json"
require "socket"
require "tmpdir"

require_relative "../freedom_patches/landlock_capture_fork"
require_relative "operations"

module DiscourseVips
  class Broker
    DEFAULT_TIMEOUT_SECONDS = 5
    private_constant :DEFAULT_TIMEOUT_SECONDS

    DEFAULT_READ_PATHS = %w[/bin /lib /lib64 /usr].freeze
    private_constant :DEFAULT_READ_PATHS

    FONTCONFIG_READ_PATHS = %w[/etc/fonts /var/cache/fontconfig].freeze
    private_constant :FONTCONFIG_READ_PATHS

    DYNAMIC_LINKER_CACHE_PATH = "/etc/ld.so.cache"
    private_constant :DYNAMIC_LINKER_CACHE_PATH

    ALLOW_UNSUPPORTED = %w[development test].include?(
      ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development",
    )
    private_constant :ALLOW_UNSUPPORTED

    RLIMITS = {
      cpu_seconds: 5,
      memory_bytes: 4 * 1024 * 1024 * 1024,
      file_size_bytes: 10 * 1024 * 1024 * 1024,
      open_files: 1024,
    }.freeze
    private_constant :RLIMITS

    MAX_OUTPUT_BYTES = 64 * 1024
    private_constant :MAX_OUTPUT_BYTES

    MAX_REQUEST_BYTES = 64 * 1024
    private_constant :MAX_REQUEST_BYTES

    REQUEST_TIMEOUT_SECONDS = 1
    private_constant :REQUEST_TIMEOUT_SECONDS

    OPERATIONS = {
      "version" => :version,
      "generate_letter_avatar" => :generate_letter_avatar,
      "resize_letter_avatar" => :resize_letter_avatar,
      "dominant_color" => :dominant_color,
      "svg_to_png" => :svg_to_png,
    }.freeze
    private_constant :OPERATIONS

    def initialize(socket_path:, parent_pid: nil, allow_unsupported: ALLOW_UNSUPPORTED)
      @socket_path = socket_path
      @parent_pid = parent_pid
      @allow_unsupported = allow_unsupported
      @children = []
      @stopping = false
    end

    def run
      @broker_pid = Process.pid
      FileUtils.mkdir_p(File.dirname(@socket_path))
      FileUtils.rm_f(@socket_path)
      @server = UNIXServer.new(@socket_path)
      socket_stat = File.stat(@socket_path)
      @socket_identity = [socket_stat.dev, socket_stat.ino]
      File.chmod(0o600, @socket_path)
      trap_signals

      until @stopping || !parent_alive?
        reap_children
        next if !IO.select([@server], nil, nil, 1)

        connection = @server.accept_nonblock(exception: false)
        spawn_connection(connection) if connection != :wait_readable
      end
    rescue IOError, Errno::EBADF
    ensure
      @server&.close
      wait_for_children
      remove_socket
    end

    private

    def trap_signals
      %w[HUP INT TERM].each do |signal|
        Signal.trap(signal) do
          @stopping = true
          @server.close
        end
      end
    end

    def remove_socket
      socket_stat = File.stat(@socket_path)
      FileUtils.rm_f(@socket_path) if [socket_stat.dev, socket_stat.ino] == @socket_identity
    rescue Errno::ENOENT
    end

    def parent_alive?
      return true if !@parent_pid

      Process.kill(0, @parent_pid)
      true
    rescue Errno::ESRCH
      false
    end

    def reap_children
      loop do
        pid = Process.waitpid(-1, Process::WNOHANG)
        break if !pid

        @children.delete(pid)
      end
    rescue Errno::ECHILD
      @children.clear
    end

    def wait_for_children
      @children.each { |pid| Process.waitpid(pid) }
    rescue Errno::ECHILD
    end

    def spawn_connection(connection)
      pid =
        fork do
          @server.close
          %w[INT TERM HUP].each { |signal| Signal.trap(signal, "DEFAULT") }
          handle_connection(connection)
          exit! 0
        end
      @children << pid
    ensure
      connection&.close
    end

    def handle_connection(connection)
      request = JSON.parse(read_request(connection))
      response = execute(request).merge(broker_pid: @broker_pid)
      connection.puts(JSON.generate(response))
    rescue StandardError => error
      begin
        connection.puts(JSON.generate(status: "error", message: error.message))
      rescue IOError, SystemCallError
      end
    ensure
      connection.close
    end

    def read_request(connection)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + REQUEST_TIMEOUT_SECONDS
      request = +""

      loop do
        timeout = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        raise ArgumentError, "request timed out" if timeout <= 0
        raise ArgumentError, "request timed out" if !IO.select([connection], nil, nil, timeout)

        remaining = MAX_REQUEST_BYTES + 1 - request.bytesize
        chunk = connection.read_nonblock([remaining, 4096].min, exception: false)
        next if chunk == :wait_readable
        raise ArgumentError, "request ended before a newline" if chunk.nil?

        request << chunk
        newline = request.index("\n")
        return request.byteslice(0, newline) if newline

        raise ArgumentError, "request is too large" if request.bytesize > MAX_REQUEST_BYTES
      end
    end

    def execute(request)
      operation = request.fetch("operation")
      arguments = request.fetch("arguments").transform_keys(&:to_sym)
      method_name = OPERATIONS.fetch(operation)

      Dir.mktmpdir("discourse-vips-broker-") do |scratch|
        result =
          Landlock.capture_fork(
            read: read_paths(operation, arguments),
            write: [scratch, *write_paths(operation, arguments)],
            execute: [],
            timeout: DEFAULT_TIMEOUT_SECONDS,
            env: environment(scratch),
            unsetenv_others: true,
            rlimits: rlimits,
            seccomp_deny_network: true,
            max_output_bytes: MAX_OUTPUT_BYTES,
            allow_unsupported: @allow_unsupported,
          ) do
            Process.setpriority(Process::PRIO_PROCESS, 0, 10)
            value = Operations.public_send(method_name, **arguments)
            STDOUT.write(JSON.generate(value:))
          end

        return { status: "timeout" } if result.timed_out?
        return { status: "error", message: result.stderr.strip } if !result.status&.success?

        { status: "ok", **JSON.parse(result.stdout) }
      end
    end

    def rlimits
      Landlock.supported? ? RLIMITS : RLIMITS.except(:memory_bytes)
    end

    def read_paths(operation, arguments)
      operation_paths =
        case operation
        when "generate_letter_avatar"
          [arguments.fetch(:font_path), *FONTCONFIG_READ_PATHS]
        when "resize_letter_avatar"
          [arguments.fetch(:input_path)]
        when "dominant_color"
          [arguments.fetch(:input_path)]
        when "svg_to_png"
          [File.dirname(arguments.fetch(:input_path)), *FONTCONFIG_READ_PATHS]
        else
          []
        end

      [*DEFAULT_READ_PATHS, DYNAMIC_LINKER_CACHE_PATH, *operation_paths].filter do |path|
          path.to_s != "" && File.exist?(path)
        end
        .uniq
    end

    def write_paths(operation, arguments)
      case operation
      when "generate_letter_avatar", "resize_letter_avatar", "svg_to_png"
        [File.dirname(arguments.fetch(:output_path))]
      else
        []
      end
    end

    def environment(scratch)
      {
        **ENV.to_h.slice("PATH", "LANG", "LC_ALL"),
        "TMPDIR" => scratch,
        "HOME" => scratch,
        "XDG_CACHE_HOME" => scratch,
        "MALLOC_ARENA_MAX" => "2",
      }
    end
  end
end
