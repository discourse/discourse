# frozen_string_literal: true

require "fileutils"
require "msgpack"
require "rbconfig"
require "socket"
require "tmpdir"

module DiscourseVips
  class Error < RuntimeError
  end

  class WorkerUnavailable < Error
  end

  class WorkerProcess
    WORKER_GRACE_SECONDS = 2
    private_constant :WORKER_GRACE_SECONDS

    def initialize
      @state_mutex = Mutex.new
      start
    end

    def alive?
      @state_mutex.synchronize do
        return false if @closed

        Process.waitpid(@worker_pid, Process::WNOHANG).nil?
      rescue Errno::ECHILD
        false
      end
    end

    def send_command(request, timeout:)
      socket = UNIXSocket.new(@socket_path)
      socket.write(MessagePack.pack(request))
      socket.close_write

      if !IO.select([socket], nil, nil, timeout + WORKER_GRACE_SECONDS)
        raise WorkerUnavailable, "libvips worker did not respond"
      end

      payload = socket.read.to_s
      raise WorkerUnavailable, "libvips worker returned no response" if payload.empty?

      MessagePack.unpack(payload)
    rescue WorkerUnavailable
      shutdown
      raise
    rescue MessagePack::UnpackError, IOError, SystemCallError => error
      shutdown
      raise WorkerUnavailable, "libvips worker request failed: #{error.message}"
    ensure
      socket&.close unless socket&.closed?
    end

    def shutdown
      worker_pid, owner_writer, socket_directory =
        @state_mutex.synchronize do
          return if @closed

          @closed = true
          [@worker_pid, @owner_writer, @socket_directory]
        end

      owner_writer.close unless owner_writer.closed?
      wait_for_worker(worker_pid)
    rescue IOError, Errno::ECHILD
    ensure
      remove_socket_directory(socket_directory)
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
      @socket_directory = Dir.mktmpdir("discourse-vips-worker-", Rails.root.join("tmp").to_s)
      @socket_path = File.join(@socket_directory, "socket")
      server = UNIXServer.new(@socket_path)
      owner_reader, @owner_writer = IO.pipe

      @worker_pid =
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
      remove_socket_directory(@socket_directory)
      raise
    ensure
      server&.close
      owner_reader&.close
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

    def remove_socket_directory(directory)
      FileUtils.remove_entry(directory) if directory && File.exist?(directory)
    rescue SystemCallError
    end
  end
end
