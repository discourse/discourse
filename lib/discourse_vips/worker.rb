# frozen_string_literal: true

require "landlock"
require "msgpack"
require "rbconfig"
require "socket"

require_relative "operations"

module DiscourseVips
  class Worker
    MAX_REQUEST_BYTES = 64 * 1024
    private_constant :MAX_REQUEST_BYTES

    MAX_RESULT_BYTES = 8 * 1024
    private_constant :MAX_RESULT_BYTES

    FALLBACK_TIMEOUT_EXIT_STATUS = 124
    private_constant :FALLBACK_TIMEOUT_EXIT_STATUS

    RLIMITS = {
      cpu_seconds: 300,
      memory_bytes: 4 * 1024 * 1024 * 1024,
      file_size_bytes: 10 * 1024 * 1024 * 1024,
      open_files: 1024,
    }.freeze
    private_constant :RLIMITS

    FALLBACK_RLIMITS = {
      CPU: RLIMITS[:cpu_seconds],
      AS: RLIMITS[:memory_bytes],
      FSIZE: RLIMITS[:file_size_bytes],
      NOFILE: RLIMITS[:open_files],
    }.freeze
    private_constant :FALLBACK_RLIMITS

    def initialize(server:, owner_reader:)
      @server = server
      @owner_reader = owner_reader
      @landlock_supported = Landlock.supported?
    end

    def self.run_operation(request_reader:, result_writer:, expected_parent_pid:)
      if RUBY_PLATFORM.include?("linux")
        Landlock::Native.set_parent_death_signal!
        exit! 1 if Process.ppid != expected_parent_pid
      end

      payload = request_reader.read(MAX_REQUEST_BYTES + 1)
      raise ArgumentError, "libvips request is too large" if payload.bytesize > MAX_REQUEST_BYTES

      request = MessagePack.unpack(payload)
      apply_process_options(request)
      result_writer.write(MessagePack.pack(operation_response(request)))
    end

    def run
      Operations.warm

      loop do
        readable, = IO.select([@server, @owner_reader])
        break if readable.include?(@owner_reader)

        accept_connections if readable.include?(@server)
      end
    ensure
      @server.close unless @server.closed?
      @owner_reader.close unless @owner_reader.closed?
    end

    private

    def accept_connections
      loop do
        connection = @server.accept_nonblock(exception: false)
        return if connection == :wait_readable

        Thread.new(connection) { |socket| handle_connection(socket) }.report_on_exception = false
      end
    end

    def handle_connection(connection)
      payload = connection.read(MAX_REQUEST_BYTES + 1)
      if payload.bytesize > MAX_REQUEST_BYTES
        connection.read
        raise ArgumentError, "libvips request is too large"
      end

      request = MessagePack.unpack(payload)
      response = @landlock_supported ? run_sandboxed(request) : run_fallback(request)
      write_response(connection, response)
    rescue StandardError => error
      write_response(connection, "status" => "error", "message" => error.message.byteslice(0, 4096))
    ensure
      connection.close unless connection.closed?
    end

    def write_response(connection, response)
      connection.write(MessagePack.pack(response))
    rescue IOError, SystemCallError
    end

    def run_sandboxed(request)
      result =
        Landlock.fork(
          read: request.fetch("read"),
          write: request.fetch("write"),
          execute: [],
          timeout: Float(request.fetch("timeout")),
          env: child_environment(request.fetch("scratch")),
          unsetenv_others: true,
          rlimits: RLIMITS,
          seccomp_deny_network: true,
          max_output_bytes: MAX_RESULT_BYTES,
        ) do |stdout, _stderr|
          apply_nice(request)
          stdout.write(MessagePack.pack(self.class.__send__(:operation_response, request)))
        end

      return { "status" => "timeout" } if result.timed_out?
      return MessagePack.unpack(result.stdout) if result.success?

      { "status" => "error", "message" => "libvips operation failed" }
    end

    def run_fallback(request)
      request_reader, request_writer = IO.pipe
      result_reader, result_writer = IO.pipe
      pid =
        Process.spawn(
          { "RUBYLIB" => $LOAD_PATH.join(File::PATH_SEPARATOR) },
          RbConfig.ruby,
          "--disable-gems",
          $PROGRAM_NAME,
          "operation",
          "5",
          "6",
          Process.pid.to_s,
          5 => request_reader,
          6 => result_writer,
          :in => File::NULL,
          :out => File::NULL,
          :close_others => true,
        )
      request_reader.close
      result_writer.close
      request_writer.write(MessagePack.pack(request))
      request_writer.close

      _, status = Process.waitpid2(pid)
      pid = nil
      return { "status" => "timeout" } if status.exitstatus == FALLBACK_TIMEOUT_EXIT_STATUS

      payload = result_reader.read(MAX_RESULT_BYTES + 1)
      if status.success? && payload.bytesize <= MAX_RESULT_BYTES
        MessagePack.unpack(payload)
      else
        { "status" => "error", "message" => "libvips operation failed" }
      end
    ensure
      if pid
        Process.kill("KILL", pid)
        Process.waitpid(pid)
      end
      [request_reader, request_writer, result_reader, result_writer].each do |io|
        io&.close unless io&.closed?
      rescue IOError
      end
    end

    def child_environment(scratch)
      {
        "HOME" => scratch,
        "TMPDIR" => scratch,
        "XDG_CACHE_HOME" => scratch,
        "MALLOC_ARENA_MAX" => "2",
      }
    end

    def apply_nice(request)
      if request["nice"]
        Process.setpriority(Process::PRIO_PROCESS, 0, Integer(request.fetch("nice")))
      end
    end

    class << self
      private

      def operation_response(request)
        value = Operations.call(request.fetch("command"))
        { "status" => "ok", "value" => value }
      rescue StandardError => error
        { "status" => "error", "message" => error.message.byteslice(0, 4096) }
      end

      def apply_process_options(request)
        ENV.replace(
          "HOME" => request.fetch("scratch"),
          "TMPDIR" => request.fetch("scratch"),
          "XDG_CACHE_HOME" => request.fetch("scratch"),
          "MALLOC_ARENA_MAX" => "2",
        )
        if request["nice"]
          Process.setpriority(Process::PRIO_PROCESS, 0, Integer(request.fetch("nice")))
        end
        FALLBACK_RLIMITS.each do |resource, limit|
          next if resource == :AS && RUBY_PLATFORM.include?("darwin")

          Process.setrlimit(resource, limit, limit)
        end
        Thread.new do
          sleep Float(request.fetch("timeout"))
          exit! FALLBACK_TIMEOUT_EXIT_STATUS
        end
      end
    end
  end
end
