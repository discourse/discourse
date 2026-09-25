# frozen_string_literal: true

require "json"
require "socket"
require "tmpdir"

module TurboTests
  class WorkQueue
    attr_reader :path, :sequence_path

    def self.origin(id)
      match = /\A(.+\.rb)\[[1-9]\d*(?::[1-9]\d*)*\]\z/.match(id)
      raise ArgumentError, "Invalid RSpec ID" unless match
      File.expand_path(match[1])
    end

    def initialize(files:, worker_count:, events:, runtime_log: nil, startup_timeout: 120)
      @files =
        files.map { |file| File.expand_path(file.sub(/(?:\[.*\]|:\d+(?::\d+)*)\z/, "")) }.to_set
      @worker_count = worker_count
      @events = events
      @runtime_log = runtime_log
      @startup_timeout = startup_timeout
      @mutex = Mutex.new
      @connections = {}
      @workers = {}
      @completed = Set.new
      @exits = {}
    end

    def start
      @weights = runtime_weights
      @directory = Dir.mktmpdir("turbo-tests-", File.expand_path("tmp"))
      @path = File.join(@directory, "queue.sock")
      @sequence_path = File.join(@directory, "sequence.jsonl")
      @sequence = File.open(@sequence_path, "w", 0o600)
      @server = UNIXServer.new(@path)
      File.chmod(0o600, @path)
      @started_at = monotonic_time
      @thread = Thread.new { serve }
    end

    def stop
      @mutex.synchronize { stop_leasing }
    end

    def worker_exited(worker:, status:)
      @mutex.synchronize do
        @exits[worker] = status
        state = @workers[worker]
        fail_queue("worker exited before completing the protocol") unless state&.dig(:finished)
        if state&.dig(:finished) && status != state[:exit_code]
          fail_queue("worker exit status disagrees with its report")
        end
      end
    end

    def complete?
      @mutex.synchronize do
        !@error && !@stopped_at && @manifest && @exits.length == @worker_count &&
          @workers.values.all? { |state| state[:finished] } &&
          @completed == @manifest.values.flatten.to_set
      end
    end

    def close
      @mutex.synchronize do
        @closed = true
        @server&.close
        @connections.each_key { |socket| socket.close unless socket.closed? }
      end
      @thread&.join(2)
      @sequence&.close
      File.unlink(@path) if @path && File.exist?(@path)
    end

    private

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def serve
      loop do
        sockets =
          @mutex.synchronize do
            break if @closed
            check_deadlines
            [@server, *@connections.keys]
          end
        break unless sockets
        readable = IO.select(sockets, nil, nil, 0.1)&.first || []
        @mutex.synchronize do
          break if @closed
          readable.each do |socket|
            if socket == @server
              client = @server.accept_nonblock(exception: false)
              @connections[client] = { buffer: +"" } unless client == :wait_readable
            else
              read_connection(socket)
            end
          end
        end
      end
    rescue IOError, Errno::EBADF
      @mutex.synchronize { fail_queue("work queue IO failed") unless @closed }
    rescue StandardError
      @mutex.synchronize { fail_queue("work queue failed") unless @closed }
    end

    def check_deadlines
      return if @stopped_at
      elapsed = monotonic_time - @started_at
      if @workers.length < @worker_count && elapsed > @startup_timeout
        fail_queue("workers did not agree on a manifest before the startup deadline")
      end
    end

    def read_connection(socket)
      state = @connections.fetch(socket)
      chunk = socket.read_nonblock(65_536, exception: false)
      return if chunk == :wait_readable
      if chunk.nil?
        fail_queue("worker disconnected before finishing") unless state[:finished] || @stopped_at
        @connections.delete(socket)
        socket.close
        return
      end
      state[:buffer] << chunk
      raise "Work queue message too large" if state[:buffer].bytesize > 8_388_608
      while (newline = state[:buffer].index("\n"))
        message = JSON.parse(state[:buffer].slice!(0..newline))
        handle_request(socket: socket, state: state, message: message)
      end
    rescue JSON::ParserError, ArgumentError, KeyError, TypeError
      fail_queue("worker sent an invalid work queue message")
    end

    def handle_request(socket:, state:, message:)
      case message.fetch("type")
      when "ready"
        worker = Integer(message.fetch("worker"))
        raise ArgumentError unless (1..@worker_count).cover?(worker) && !@workers.key?(worker)
        manifest = normalize_manifest(message.fetch("manifest"))
        if @manifest && @manifest != manifest
          fail_queue("worker manifests disagree")
        else
          @manifest ||= manifest
        end
        state[:worker] = worker
        state[:socket] = socket
        @workers[worker] = state
        if @stopped_at
          respond(socket: socket, type: "stop")
        elsif @workers.length == @worker_count
          @pending = ordered_files
          @workers.each_value { |registered| respond(socket: registered[:socket], type: "ready") }
        end
      when "next"
        raise ArgumentError unless state[:worker] && @pending
        completed = message.fetch("completed")
        raise ArgumentError unless completed.is_a?(Array) && completed.uniq == completed
        expected = state[:file] ? @manifest.fetch(state[:file]) : []
        if message["cancelled"]
          stop_leasing
          @events << { type: "dynamic_cancelled" }
        end
        unless (@stopped_at ? (completed - expected).empty? : completed.sort == expected)
          fail_queue("worker completed a different set of examples than its lease")
        end
        fail_queue("example completed more than once") unless (@completed & completed.to_set).empty?
        @completed.merge(completed)
        state[:file] = nil
        if @stopped_at || @pending.empty?
          state[:drained] = true
          respond(socket: socket, type: "stop")
        else
          state[:file] = @pending.shift
          @sequence.puts(JSON.generate(worker: state[:worker], file: state[:file]))
          @sequence.flush
          @events << {
            type: "message",
            message:
              "TURBO_RSPEC_LEASE #{JSON.generate(worker: state[:worker], file: state[:file].delete_prefix("#{Dir.pwd}/"))}",
          }
          respond(socket: socket, type: "file", file: state[:file])
        end
      when "finish"
        if !state[:worker] || !(state[:drained] || @stopped_at || @manifest.empty?)
          raise ArgumentError
        end
        state[:finished] = true
        state[:exit_code] = Integer(message.fetch("exit_code"))
        if message.fetch("non_example_failure")
          fail_queue("worker reported a failure outside examples")
        end
        respond(socket: socket, type: "finished")
      else
        raise ArgumentError
      end
    end

    def normalize_manifest(manifest)
      raise ArgumentError unless manifest.is_a?(Hash)
      result = {}
      manifest.each do |file, ids|
        raise ArgumentError unless @files.include?(file) && ids.is_a?(Array)
        unless ids.uniq == ids && ids.all? { |id| self.class.origin(id) == file }
          raise ArgumentError
        end
        result[file] = ids.sort unless ids.empty?
      end
      result.sort.to_h
    end

    def runtime_weights
      weights = {}
      if @runtime_log && File.file?(@runtime_log)
        File.foreach(@runtime_log) do |line|
          file, separator, seconds = line.strip.rpartition(":")
          duration = Float(seconds, exception: false)
          weights[File.expand_path(file)] = duration if separator != "" && duration&.finite? &&
            duration >= 0
        end
      end
      weights
    end

    def ordered_files
      @manifest.keys.sort_by do |file|
        duration = @weights.fetch(file) { @weights.values.max || File.size(file).to_f }
        [-duration, file]
      end
    end

    def respond(socket:, **message)
      socket.puts(JSON.generate(message))
    rescue Errno::EPIPE, Errno::ECONNRESET
      fail_queue("worker stopped reading work queue responses")
    end

    def stop_leasing
      return if @stopped_at
      @stopped_at = monotonic_time
      @workers.each_value { |state| respond(socket: state[:socket], type: "stop") } unless @pending
    end

    def fail_queue(message)
      return if @error
      @error = true
      stop_leasing
      @events << { type: "dynamic_error", message: message }
    end
  end
end
