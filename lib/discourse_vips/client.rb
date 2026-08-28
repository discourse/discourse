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
          raise Error, "libvips operation timed out"
        else
          raise Error, response["message"].presence || "libvips operation failed"
        end
      end
    end

    def self.before_fork
      reset_worker_process
    end

    def self.send_command(request, timeout:)
      socket = UNIXSocket.new(worker_socket_path)

      socket.write(MessagePack.pack(request))
      socket.close_write

      if !IO.select([socket], nil, nil, timeout + WORKER_GRACE_SECONDS)
        raise WorkerUnavailable, "libvips worker did not respond"
      end

      payload = socket.read.to_s
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
