# frozen_string_literal: true

require_relative "worker_process"

module DiscourseVips
  module Monitor
    def self.configure(root:, environment:)
      @root = root
      @monitor_pid = Process.pid
      @worker_socket_path = File.join(root, "tmp/discourse-vips-worker", environment, "socket")
      @socket_path = File.join(File.dirname(@worker_socket_path), "monitor-#{@monitor_pid}.sock")
    end

    def self.start(logger:)
      @logger = logger
      FileUtils.mkdir_p(File.dirname(@socket_path), mode: 0o700)
      File.chmod(0o700, File.dirname(@socket_path))
      FileUtils.mkdir_p(File.dirname(pid_file))
      @server = UNIXServer.new(@socket_path)
      File.chmod(0o600, @socket_path)
      @thread = Thread.new { serve }
      at_exit { shutdown if Process.pid == @monitor_pid }
    end

    def self.ensure_running
      socket = Addrinfo.unix(@socket_path).connect(timeout: 5)
      socket.write("E")
      raise WorkerUnavailable, "libvips monitor did not respond" unless socket.wait_readable(10)
      unless socket.gets == "OK\n"
        raise WorkerUnavailable, "libvips monitor could not start the worker"
      end
      nil
    rescue SystemCallError, IOError => error
      raise WorkerUnavailable, "libvips monitor request failed: #{error.message}"
    ensure
      socket&.close
    end

    def self.shutdown
      return if !@server

      @thread.kill
      @thread.join
      worker_pid = @worker&.pid
      @worker&.shutdown
      @worker = nil
      @server.close
      @server = nil
      File.unlink(@socket_path)
      if worker_pid && File.exist?(pid_file) && File.read(pid_file).to_i == worker_pid
        File.unlink(pid_file)
      end
    end

    def self.serve
      loop do
        client = @server.accept
        next unless client.wait_readable(5) && client.read(1) == "E"

        Pitchfork.prevent_fork do
          if !@worker || !@worker.alive?
            @worker&.shutdown
            @worker = WorkerProcess.new(socket_path: @worker_socket_path, root: @root)
            File.write(pid_file, @worker.pid)
          end
        end
        client.write("OK\n")
      rescue StandardError => error
        @logger.error("libvips monitor: #{error.class}: #{error.message}")
        begin
          client&.write("ERROR\n")
        rescue StandardError
          nil
        end
      ensure
        client&.close
      end
    end
    private_class_method :serve

    def self.pid_file
      File.join(@root, "tmp/pids/discourse_vips_0.pid")
    end
    private_class_method :pid_file
  end
end
