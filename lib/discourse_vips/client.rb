# frozen_string_literal: true

require "image_processing/instrumentation"
require "msgpack"
require "socket"

require_relative "worker_process"

module DiscourseVips
  module Client
    DEFAULT_TIMEOUT_SECONDS = 30
    private_constant :DEFAULT_TIMEOUT_SECONDS

    WORKER_GRACE_SECONDS = 2
    private_constant :WORKER_GRACE_SECONDS

    @owner_pid = Process.pid
    @shared_worker = false
    @worker_process_mutex = Mutex.new

    def self.use_shared_worker
      @shared_worker = true
      reset_worker_process
    end

    def self.call(command, operation:, timeout: DEFAULT_TIMEOUT_SECONDS, nice: 10)
      payload = { command: command.map(&:to_s), timeout:, nice: }

      ImageProcessing::Instrumentation.instrument(operation:) do
        response = send_command(payload, timeout:)
        case response["status"]
        when "ok"
          response["value"]
        when "timeout"
          raise OperationTimeout, "libvips operation timed out"
        when "invalid_image"
          raise InvalidImage, response["message"].presence || "invalid image"
        else
          raise Error, response["message"].presence || "libvips operation failed"
        end
      end
    end

    def self.before_fork
      reset_worker_process
    end

    def self.send_command(request, timeout:)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout + WORKER_GRACE_SECONDS
      socket = connect_socket(deadline:)

      write_request(socket, MessagePack.pack(request), deadline:)
      socket.close_write

      payload = read_response(socket, deadline:)
      raise WorkerUnavailable, "libvips worker returned no response" if payload.empty?

      MessagePack.unpack(payload)
    rescue WorkerUnavailable
      reset_worker_process if !@shared_worker
      raise
    rescue MessagePack::UnpackError, IOError, SystemCallError => error
      reset_worker_process if !@shared_worker

      raise WorkerUnavailable, "libvips worker request failed: #{error.message}"
    ensure
      socket&.close unless socket&.closed?
    end
    private_class_method :send_command

    def self.connect_socket(deadline:)
      Addrinfo.unix(worker_socket_path).connect(timeout: remaining_time(deadline))
    rescue IO::TimeoutError
      raise WorkerUnavailable, "libvips worker did not respond"
    end
    private_class_method :connect_socket

    def self.write_request(socket, request, deadline:)
      offset = 0
      while offset < request.bytesize
        written = socket.write_nonblock(request.byteslice(offset..), exception: false)
        if written == :wait_writable
          wait_for_socket(socket, deadline:, readable: false)
        else
          offset += written
        end
      end
    end
    private_class_method :write_request

    def self.read_response(socket, deadline:)
      response = +""
      loop do
        chunk = socket.read_nonblock(16 * 1024, exception: false)
        return response if chunk.nil?

        if chunk == :wait_readable
          wait_for_socket(socket, deadline:, readable: true)
        else
          response << chunk
        end
      end
    end
    private_class_method :read_response

    def self.wait_for_socket(socket, deadline:, readable:)
      timeout = remaining_time(deadline)
      ready =
        readable ? IO.select([socket], nil, nil, timeout) : IO.select(nil, [socket], nil, timeout)

      raise WorkerUnavailable, "libvips worker did not respond" if !ready
    end
    private_class_method :wait_for_socket

    def self.remaining_time(deadline)
      remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      raise WorkerUnavailable, "libvips worker did not respond" if !remaining.positive?

      remaining
    end
    private_class_method :remaining_time

    def self.worker_socket_path
      return WorkerProcess.shared_socket_path if @shared_worker

      worker_process.socket_path
    end
    private_class_method :worker_socket_path

    def self.worker_process
      reset_after_fork if @owner_pid != Process.pid

      @worker_process_mutex.synchronize do
        if @worker_process && !@worker_process.alive?
          @worker_process.shutdown
          @worker_process = nil
        end
        @worker_process ||= WorkerProcess.new
      end
    rescue SystemCallError => error
      raise WorkerUnavailable, "libvips worker could not start: #{error.message}"
    end
    private_class_method :worker_process

    def self.reset_after_fork
      @worker_process&.discard
      @owner_pid = Process.pid
      @worker_process = nil
      @worker_process_mutex = Mutex.new
    end
    private_class_method :reset_after_fork

    def self.reset_worker_process
      reset_after_fork if @owner_pid != Process.pid
      worker_process =
        @worker_process_mutex.synchronize { @worker_process.tap { @worker_process = nil } }
      worker_process&.shutdown
    end
    private_class_method :reset_worker_process
  end
end
