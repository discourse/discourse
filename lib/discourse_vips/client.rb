# frozen_string_literal: true

require "image_processing/instrumentation"

require_relative "worker_process"

module DiscourseVips
  module Client
    DEFAULT_TIMEOUT_SECONDS = 30
    private_constant :DEFAULT_TIMEOUT_SECONDS

    @owner_pid = Process.pid
    @worker_process_mutex = Mutex.new

    def self.call(command, operation:, timeout: DEFAULT_TIMEOUT_SECONDS, nice: 10)
      payload = { command: command.map(&:to_s), timeout:, nice: }

      ImageProcessing::Instrumentation.instrument(operation:) do
        response = worker_process.send_command(payload, timeout:)
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
