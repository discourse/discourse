# frozen_string_literal: true

require "json"
require "landlock"
require "rbconfig"

require_relative "operations"

module DiscourseVips
  class Worker
    SCRIPT_PATH = File.expand_path("../../script/discourse_vips_worker", __dir__)
    private_constant :SCRIPT_PATH

    MAX_REQUEST_BYTES = 64 * 1024
    private_constant :MAX_REQUEST_BYTES

    MAX_RESULT_BYTES = 8 * 1024
    private_constant :MAX_RESULT_BYTES

    TERMINATE_GRACE_SECONDS = 0.5
    private_constant :TERMINATE_GRACE_SECONDS

    RLIMITS = {
      CPU: 300,
      AS: 4 * 1024 * 1024 * 1024,
      FSIZE: 10 * 1024 * 1024 * 1024,
      NOFILE: 1024,
    }.freeze
    private_constant :RLIMITS

    Child =
      Struct.new(:id, :pid, :reader, :deadline, :kill_deadline, :timed_out, keyword_init: true)
    private_constant :Child

    def initialize(request_reader:, response_writer:)
      @request_reader = request_reader
      @response_writer = response_writer
      @response_writer.sync = true
      @request_buffer = +""
      @children = {}
      @last_request_id = 0
      @stopping = false
    end

    def self.run_operation(request_reader:, result_writer:)
      payload = request_reader.read(MAX_REQUEST_BYTES + 1)
      raise ArgumentError, "libvips request is too large" if payload.bytesize > MAX_REQUEST_BYTES

      request = JSON.parse(payload)
      new(request_reader:, response_writer: result_writer).send(
        :execute_operation,
        request,
        request_reader,
        result_writer,
      )
    end

    def run
      Operations.warm
      @signal_reader, @signal_writer = IO.pipe
      trap_signals

      until @stopping && @children.empty?
        readers = [@signal_reader, *@children.values.map(&:reader)]
        readers << @request_reader if !@stopping
        readable, = IO.select(readers, nil, nil, next_timeout)
        reap_children(readable)
        read_requests if readable&.include?(@request_reader)
        drain_signal_pipe if readable&.include?(@signal_reader)
        @children.each_value { |child| terminate(child) } if @stopping
        expire_children
      end
    ensure
      terminate_children
      [@request_reader, @response_writer, @signal_reader, @signal_writer].each do |io|
        io&.close unless io.closed?
      rescue IOError
      end
    end

    private

    def trap_signals
      %w[HUP INT TERM].each do |signal|
        Signal.trap(signal) do
          @stopping = true
          wake
        end
      end
    end

    def wake
      @signal_writer.write_nonblock(".", exception: false)
    rescue IOError, Errno::EPIPE
    end

    def drain_signal_pipe
      @signal_reader.read_nonblock(4096, exception: false)
    end

    def read_requests
      chunk = @request_reader.read_nonblock(16 * 1024, exception: false)
      return if chunk == :wait_readable

      if chunk.nil?
        if @request_buffer.empty?
          @stopping = true
        else
          fail_worker("incomplete libvips request")
        end
        @request_reader.close
        return
      end

      @request_buffer << chunk
      while (newline = @request_buffer.index("\n"))
        line = @request_buffer.slice!(0, newline + 1)
        raise ArgumentError, "libvips request is too large" if line.bytesize > MAX_REQUEST_BYTES

        request = JSON.parse(line)
        id = Integer(request.fetch("id"))
        raise ArgumentError, "invalid libvips request id" if id <= @last_request_id

        @last_request_id = id
        spawn_operation(request, id)
      end
      if @request_buffer.bytesize > MAX_REQUEST_BYTES
        raise ArgumentError, "libvips request is too large"
      end
    rescue JSON::ParserError, KeyError, ArgumentError => error
      fail_worker(error.message)
    end

    def spawn_operation(request, id)
      result_reader, result_writer = IO.pipe
      result_writer.sync = true
      pid =
        if RUBY_PLATFORM.include?("darwin")
          spawn_operation_process(request, result_writer)
        else
          fork { execute_operation(request, result_reader, result_writer) }
        end
      result_writer.close
      @children[pid] = Child.new(
        id:,
        pid:,
        reader: result_reader,
        deadline: monotonic_time + Float(request.fetch("timeout")),
        kill_deadline: nil,
        timed_out: false,
      )
    rescue StandardError => error
      result_reader&.close
      result_writer&.close
      write_response(id: request["id"], status: "error", message: error.message)
    end

    def spawn_operation_process(request, result_writer)
      request_reader, request_writer = IO.pipe
      pid =
        Process.spawn(
          { "RUBYLIB" => $LOAD_PATH.join(File::PATH_SEPARATOR) },
          RbConfig.ruby,
          "--disable-gems",
          SCRIPT_PATH,
          "operation",
          "5",
          "6",
          5 => request_reader,
          6 => result_writer,
          :in => File::NULL,
          :out => File::NULL,
          :close_others => true,
        )
      request_reader.close
      request_writer.write(JSON.generate(request))
      request_writer.close
      pid
    ensure
      request_reader&.close unless request_reader&.closed?
      request_writer&.close unless request_writer&.closed?
    end

    def execute_operation(request, result_reader, result_writer)
      result_reader.close
      close_inherited_io(result_writer)
      %w[HUP INT TERM].each { |signal| Signal.trap(signal, "DEFAULT") }
      apply_environment(request.fetch("scratch"))
      apply_sandbox(request)
      if request["nice"]
        Process.setpriority(Process::PRIO_PROCESS, 0, Integer(request.fetch("nice")))
      end

      value = Operations.call(request.fetch("command"))
      result_writer.write(JSON.generate(status: "ok", value:))
      exit! 0
    rescue Exception => error
      result_writer.write(JSON.generate(status: "error", message: error.message.byteslice(0, 4096)))
      exit! 1
    end

    def close_inherited_io(result_writer)
      [
        @request_reader,
        @response_writer,
        @signal_reader,
        @signal_writer,
        *@children.values.map(&:reader),
      ].each do |io|
        io&.close unless io&.closed? || io.equal?(result_writer)
      rescue IOError
      end
    end

    def apply_environment(scratch)
      ENV.replace(
        "HOME" => scratch,
        "TMPDIR" => scratch,
        "XDG_CACHE_HOME" => scratch,
        "MALLOC_ARENA_MAX" => "2",
      )
    end

    def apply_sandbox(request)
      if Landlock.supported?
        Landlock.restrict!(read: request.fetch("read"), write: request.fetch("write"), execute: [])
        Landlock.seccomp_deny_network!
      end

      RLIMITS.each do |resource, limit|
        next if resource == :AS && RUBY_PLATFORM.include?("darwin")

        Process.setrlimit(resource, limit, limit)
      end
    end

    def next_timeout
      deadlines =
        @children.values.filter_map do |child|
          child.timed_out ? child.kill_deadline : child.deadline
        end
      return nil if deadlines.empty?

      [deadlines.min - monotonic_time, 0].max
    end

    def expire_children
      now = monotonic_time
      @children.each_value do |child|
        if !child.timed_out && now >= child.deadline
          terminate(child)
        elsif child.kill_deadline && now >= child.kill_deadline
          signal("KILL", child.pid)
          child.kill_deadline = nil
        end
      end
    end

    def terminate(child)
      return if child.timed_out

      signal("TERM", child.pid)
      child.timed_out = true
      child.kill_deadline = monotonic_time + TERMINATE_GRACE_SECONDS
    end

    def signal(signal, pid)
      Process.kill(signal, pid)
    rescue Errno::ESRCH, Errno::EPERM
    end

    def reap_children(readable)
      @children
        .values
        .select { |child| readable&.include?(child.reader) }
        .each do |child|
          payload = child.reader.read(MAX_RESULT_BYTES + 1).to_s
          child.reader.close
          _, status = Process.waitpid2(child.pid)
          @children.delete(child.pid)
          response = parse_result(payload, status)
          response = { status: "timeout" } if child.timed_out
          write_response(id: child.id, **response)
        end
    end

    def parse_result(payload, status)
      if payload.bytesize > MAX_RESULT_BYTES
        return { status: "error", message: "libvips result is too large" }
      end

      response = JSON.parse(payload)
      return response if status.success?

      message = response["message"].to_s
      { status: "error", message: message.empty? ? "libvips operation failed" : message }
    rescue JSON::ParserError
      { status: "error", message: "libvips operation failed" }
    end

    def write_response(response)
      @response_writer.write(JSON.generate(response) << "\n")
    rescue IOError, Errno::EPIPE
      @stopping = true
      @children.each_value { |child| terminate(child) }
    end

    def fail_worker(message)
      write_response(id: nil, status: "error", message:)
      @stopping = true
      @children.each_value { |child| terminate(child) }
    end

    def terminate_children
      children = @children.values
      @children = {}
      children.each { |child| signal("KILL", child.pid) }
      children.each do |child|
        Process.waitpid(child.pid)
        child.reader.close
      rescue Errno::ECHILD, IOError
      end
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
