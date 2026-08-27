# frozen_string_literal: true

require "landlock"
require "msgpack"
require "socket"

require_relative "operations"

module DiscourseVips
  class Worker
    MAX_REQUEST_BYTES = 64 * 1024
    private_constant :MAX_REQUEST_BYTES

    MAX_RESULT_BYTES = 8 * 1024
    private_constant :MAX_RESULT_BYTES

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
      response = @landlock_supported ? run_sandboxed(request) : run_forked(request)
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

    def run_forked(request)
      result_reader, result_writer = IO.pipe
      parent_pid = Process.pid
      pid = fork { execute_forked(request, parent_pid, result_reader, result_writer) }
      result_writer.close

      if !IO.select([result_reader], nil, nil, Float(request.fetch("timeout")))
        terminate_fork(pid)
        pid = nil
        return { "status" => "timeout" }
      end

      payload = result_reader.read(MAX_RESULT_BYTES + 1)
      Process.waitpid(pid)
      pid = nil
      if payload.bytesize <= MAX_RESULT_BYTES
        MessagePack.unpack(payload)
      else
        { "status" => "error", "message" => "libvips operation failed" }
      end
    rescue MessagePack::UnpackError
      { "status" => "error", "message" => "libvips operation failed" }
    ensure
      terminate_fork(pid) if pid
      [result_reader, result_writer].each do |io|
        io&.close unless io&.closed?
      rescue IOError
      end
    end

    def execute_forked(request, parent_pid, result_reader, result_writer)
      result_reader.close
      result_writer.sync = true
      if RUBY_PLATFORM.include?("linux")
        Landlock::Native.set_parent_death_signal!
        exit! 1 if Process.ppid != parent_pid
      end
      close_inherited_ios(result_writer)
      self.class.__send__(:apply_process_options, request)
      result_writer.write(MessagePack.pack(self.class.__send__(:operation_response, request)))
      exit! 0
    rescue Exception => error
      result_writer.write(
        MessagePack.pack("status" => "error", "message" => error.message.byteslice(0, 4096)),
      )
      exit! 1
    end

    def close_inherited_ios(result_writer)
      ObjectSpace
        .each_object(IO)
        .to_a
        .each do |io|
          next if io.closed? || io.fileno <= 2 || io.equal?(result_writer)

          io.close
        rescue IOError
        end
    end

    def terminate_fork(pid)
      begin
        Process.kill("KILL", pid)
      rescue Errno::ESRCH
      end
      Process.waitpid(pid)
    rescue Errno::ECHILD
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
      end
    end
  end
end
