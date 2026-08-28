# frozen_string_literal: true

require "fileutils"
require "rbconfig"
require "socket"
require "tmpdir"

module DiscourseVips
  class Error < RuntimeError
  end

  class WorkerUnavailable < Error
  end

  class OperationTimeout < Error
  end

  class InvalidImage < Error
  end

  class WorkerProcess
    WORKER_GRACE_SECONDS = 2
    private_constant :WORKER_GRACE_SECONDS

    attr_reader :pid, :socket_path

    def self.shared_socket_path
      Rails.root.join("tmp", "discourse-vips-worker", Rails.env, "socket").to_s
    end

    def initialize(socket_path: nil)
      @state_mutex = Mutex.new
      @socket_path = socket_path
      start
    end

    def alive?
      @state_mutex.synchronize do
        return false if @closed

        Process.waitpid(@pid, Process::WNOHANG).nil?
      rescue Errno::ECHILD
        false
      end
    end

    def shutdown
      worker_pid, owner_writer =
        @state_mutex.synchronize do
          return if @closed

          @closed = true
          [@pid, @owner_writer]
        end

      owner_writer.close unless owner_writer.closed?
      wait_for_worker(worker_pid)
    rescue IOError, Errno::ECHILD
    ensure
      remove_socket
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

    def start
      prepare_socket_path
      server = UNIXServer.new(@socket_path)
      File.chmod(0o600, @socket_path)
      @socket_identity = File.stat(@socket_path).then { |stat| [stat.dev, stat.ino] }
      owner_reader, @owner_writer = IO.pipe

      @pid =
        Process.spawn(
          worker_environment,
          *worker_command,
          server.fileno.to_s,
          owner_reader.fileno.to_s,
          server.fileno => server,
          owner_reader.fileno => owner_reader,
          :in => File::NULL,
          :out => File::NULL,
          :close_others => true,
          :pgroup => true,
          :unsetenv_others => true,
        )
      @closed = false
    rescue Exception
      @owner_writer&.close
      remove_socket
      raise
    ensure
      server&.close
      owner_reader&.close
    end

    def prepare_socket_path
      if @socket_path
        socket_directory = File.dirname(@socket_path)
        FileUtils.mkdir_p(socket_directory, mode: 0o700)
        File.chmod(0o700, socket_directory)
        FileUtils.rm_f(@socket_path)
      else
        socket_directory = Dir.mktmpdir("discourse-vips-worker-", Rails.root.join("tmp").to_s)
        @socket_path = File.join(socket_directory, "socket")
      end
    end

    def worker_command
      load_paths = [Rails.root.join("lib").to_s]
      %w[ffi landlock msgpack ruby-vips].each do |gem_name|
        load_paths.concat(Gem.loaded_specs.fetch(gem_name).full_require_paths)
      end

      [
        RbConfig.ruby,
        "--disable-gems",
        *load_paths.uniq.flat_map { |path| ["-I", path] },
        Rails.root.join("script/discourse_vips_worker").to_s,
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

    def wait_for_worker(worker_pid)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + WORKER_GRACE_SECONDS
      while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        return if Process.waitpid(worker_pid, Process::WNOHANG)

        sleep 0.01
      end

      terminate_worker_group(worker_pid)
      Process.waitpid(worker_pid)
    rescue Errno::ECHILD, Errno::ESRCH
    ensure
      terminate_worker_group(worker_pid)
    end

    def terminate_worker_group(worker_pid)
      Process.kill("KILL", -worker_pid)
    rescue Errno::ESRCH
    end

    def remove_socket
      if File.exist?(@socket_path)
        stat = File.stat(@socket_path)
        return if [stat.dev, stat.ino] != @socket_identity

        File.unlink(@socket_path)
      end
      Dir.rmdir(File.dirname(@socket_path))
    rescue SystemCallError
    end
  end
end
