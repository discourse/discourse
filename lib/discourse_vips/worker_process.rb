# frozen_string_literal: true

require "fileutils"
require "rbconfig"
require "securerandom"
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
    # Unix socket paths are capped at 104 bytes on macOS and 108 on Linux.
    MAX_SOCKET_PATH_BYTES = 103
    SHORT_SOCKET_PREFIX = "/tmp/discourse-vips-"
    SHORT_SOCKET_MARKER = "app-root"
    SHORT_SOCKET_CLAIM_ATTEMPTS = 10
    private_constant :WORKER_GRACE_SECONDS,
                     :MAX_SOCKET_PATH_BYTES,
                     :SHORT_SOCKET_PREFIX,
                     :SHORT_SOCKET_MARKER,
                     :SHORT_SOCKET_CLAIM_ATTEMPTS

    attr_reader :pid, :socket_path

    def self.shared_socket_path
      @shared_socket_path ||=
        begin
          path = Rails.root.join("tmp", "discourse-vips-worker", Rails.env, "socket").to_s
          if path.bytesize <= MAX_SOCKET_PATH_BYTES
            path
          else
            File.join(short_socket_directory, Rails.env, "socket")
          end
        end
    end

    # Deep checkouts (e.g. git worktrees) overflow the socket path limit, so the
    # socket moves to /tmp under the checkout's (truncated) directory name. Every
    # process resolves this path independently, so the directory records which
    # app root owns it and a random suffix is only added when the name is taken.
    def self.short_socket_directory
      tail = File.join("", Rails.env, "socket")
      budget =
        MAX_SOCKET_PATH_BYTES - SHORT_SOCKET_PREFIX.bytesize - "-000".bytesize - tail.bytesize
      name = File.basename(Rails.root.to_s).byteslice(0, budget).scrub("")
      base = "#{SHORT_SOCKET_PREFIX}#{name}"

      existing = [base, *Dir.glob("#{base}-[0-9][0-9][0-9]").sort]
      if (owned = existing.find { |dir| short_socket_directory_owned?(dir) })
        return owned
      end
      return base if claim_short_socket_directory(base)

      SHORT_SOCKET_CLAIM_ATTEMPTS.times do
        dir = format("%s-%03d", base, SecureRandom.random_number(1000))
        return dir if claim_short_socket_directory(dir)
      end

      raise Error, "Could not claim a socket directory under #{base}"
    end
    private_class_method :short_socket_directory

    def self.short_socket_directory_owned?(dir)
      stat = File.lstat(dir)
      stat.directory? && stat.owned? &&
        File.read(File.join(dir, SHORT_SOCKET_MARKER)) == Rails.root.to_s
    rescue Errno::ENOENT, Errno::ENOTDIR, Errno::EACCES
      false
    end
    private_class_method :short_socket_directory_owned?

    # Renaming a pre-filled staging dir into place makes the claim atomic, so a
    # concurrent process never sees the directory without its marker.
    def self.claim_short_socket_directory(dir)
      staging = Dir.mktmpdir(File.basename(dir) + "-staging-", File.dirname(dir))
      File.write(File.join(staging, SHORT_SOCKET_MARKER), Rails.root.to_s)
      File.rename(staging, dir)
      true
    rescue Errno::EEXIST, Errno::ENOTEMPTY, Errno::EPERM, Errno::EACCES
      FileUtils.rm_rf(staging) if staging
      short_socket_directory_owned?(dir)
    end
    private_class_method :claim_short_socket_directory

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
        socket_directory = Dir.mktmpdir("vips-")
        @socket_path = File.join(socket_directory, "socket")
      end
    end

    def worker_command
      load_paths = [Rails.root.join("lib").to_s]
      %w[ffi landlock logger msgpack ruby-vips].each do |gem_name|
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
