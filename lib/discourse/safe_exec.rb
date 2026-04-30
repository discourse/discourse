# frozen_string_literal: true

require "timeout"
require "discourse/seccomp"

begin
  require "landlock" if RUBY_PLATFORM.include?("linux")
rescue LoadError
end

module Discourse
  class SafeExec
    OutputTooLargeError = Class.new(StandardError)

    DEFAULT_READ_PATHS = %w[/bin /etc /lib /lib64 /usr].freeze
    DEFAULT_EXECUTE_PATHS = %w[/bin /lib /lib64 /usr].freeze
    READ_CHUNK_BYTES = 16 * 1024

    def self.capture(
      *command,
      read: [],
      write: [],
      execute: [],
      timeout: nil,
      failure_message: "",
      success_status_codes: [0],
      env: nil,
      unsetenv_others: false,
      chdir: nil,
      connect_tcp: nil,
      bind_tcp: [],
      rlimits: {},
      seccomp_deny_network: false,
      max_output_bytes: nil,
      truncate_output: false
    )
      if !landlock_supported?
        if unsetenv_others || (rlimits && !rlimits.empty?) || seccomp_deny_network ||
             max_output_bytes
          return(
            capture_without_landlock(
              command,
              timeout: timeout,
              failure_message: failure_message,
              success_status_codes: success_status_codes,
              env: env,
              unsetenv_others: unsetenv_others,
              chdir: chdir,
              rlimits: rlimits,
              seccomp_deny_network: seccomp_deny_network,
              max_output_bytes: max_output_bytes,
              truncate_output: truncate_output,
            )
          )
        end

        fallback_command = env ? [env, *command] : command
        return(
          Discourse::Utils.execute_command(
            *fallback_command,
            timeout: timeout,
            failure_message: failure_message,
            success_status_codes: success_status_codes,
            chdir: chdir || ".",
          )
        )
      end

      stdout, stderr, status, output_truncated =
        capture_with_landlock(
          command,
          read: read,
          write: write,
          execute: execute,
          timeout: timeout,
          env: env,
          unsetenv_others: unsetenv_others,
          chdir: chdir,
          connect_tcp: connect_tcp,
          bind_tcp: bind_tcp,
          rlimits: rlimits,
          seccomp_deny_network: seccomp_deny_network,
          max_output_bytes: max_output_bytes,
          truncate_output: truncate_output,
        )

      return stdout if output_truncated && truncate_output

      if !status.exited? || !success_status_codes.include?(status.exitstatus)
        message =
          [command.join(" "), failure_message, stderr].filter { |part| part.to_s != "" }.join("\n")
        raise Discourse::Utils::CommandError.new(
                message,
                stdout: stdout,
                stderr: stderr,
                status: status,
              )
      end

      stdout
    rescue OutputTooLargeError => e
      message =
        [command.join(" "), failure_message, e.message].filter { |part| part.to_s != "" }.join("\n")
      raise Discourse::Utils::CommandError.new(message)
    end

    def self.landlock_supported?
      defined?(::Landlock) && ::Landlock.supported?
    rescue ::Landlock::Error
      false
    end

    def self.default_read_paths
      existing_paths(DEFAULT_READ_PATHS)
    end

    def self.default_execute_paths
      existing_paths(DEFAULT_EXECUTE_PATHS)
    end

    def self.existing_paths(paths)
      Array(paths).filter { |path| path.to_s != "" && File.exist?(path) }.uniq
    end

    def self.sandbox_connect_tcp_ports(connect_tcp)
      return connect_tcp if !connect_tcp.nil?
      return [] if ::Landlock.abi_version < 4

      [0]
    end

    def self.apply_rlimits(rlimits)
      rlimits.each do |name, value|
        next if value.nil?

        resource = rlimit_resource(name)
        next if resource.nil?

        Process.setrlimit(resource, value, value)
      rescue NotImplementedError, SystemCallError
        next
      end
    end

    def self.rlimit_resource(name)
      case name
      when :cpu_seconds
        Process::RLIMIT_CPU
      when :memory_bytes
        Process::RLIMIT_AS
      when :file_size_bytes
        Process::RLIMIT_FSIZE
      when :open_files
        Process::RLIMIT_NOFILE
      when :processes
        Process.const_defined?(:RLIMIT_NPROC) ? Process::RLIMIT_NPROC : nil
      else
        raise ArgumentError, "Unknown rlimit: #{name}"
      end
    end

    def self.apply_seccomp(deny_network)
      return if !deny_network
      return if !Discourse::Seccomp.supported?

      Discourse::Seccomp.deny_network!
    rescue Discourse::Seccomp::Error, NotImplementedError, SystemCallError
      nil
    end

    private_class_method def self.capture_without_landlock(
      command,
      timeout:,
      failure_message:,
      success_status_codes:,
      env:,
      unsetenv_others:,
      chdir:,
      rlimits:,
      seccomp_deny_network:,
      max_output_bytes:,
      truncate_output:
    )
      stdout, stderr, status, output_truncated =
        capture_process(
          command,
          timeout: timeout,
          env: env,
          unsetenv_others: unsetenv_others,
          chdir: chdir,
          rlimits: rlimits,
          seccomp_deny_network: seccomp_deny_network,
          max_output_bytes: max_output_bytes,
          truncate_output: truncate_output,
        )

      if !status.exited? || !success_status_codes.include?(status.exitstatus)
        message =
          [command.join(" "), failure_message, stderr].filter { |part| part.to_s != "" }.join("\n")
        raise Discourse::Utils::CommandError.new(
                message,
                stdout: stdout,
                stderr: stderr,
                status: status,
              )
      end

      stdout
    end

    private_class_method def self.capture_process(
      command,
      timeout:,
      env:,
      unsetenv_others:,
      chdir:,
      rlimits:,
      seccomp_deny_network:,
      max_output_bytes:,
      truncate_output:,
      before_exec: nil
    )
      stdout_read, stdout_write = IO.pipe
      stderr_read, stderr_write = IO.pipe

      pid =
        fork do
          begin
            stdout_read.close
            stderr_read.close
            Process.setsid
            STDOUT.reopen(stdout_write)
            STDERR.reopen(stderr_write)
            stdout_write.close
            stderr_write.close

            Dir.chdir(chdir) if chdir # rubocop:disable Discourse/NoChdir
            apply_rlimits(rlimits)
            before_exec&.call
            apply_seccomp(seccomp_deny_network)

            exec_options = { close_others: true }
            exec_options[:unsetenv_others] = true if unsetenv_others
            if env
              Kernel.exec(env, *command, exec_options)
            else
              Kernel.exec(*command, exec_options)
            end
          rescue Exception => e
            warn "SafeExec child failed before exec: #{e.class}: #{e.message}"
            exit! 127
          end
        end

      stdout_write.close
      stderr_write.close

      output_state = { bytes: 0, truncated: false }
      output_mutex = Mutex.new
      stdout_thread =
        Thread.new do
          Thread.current.report_on_exception = false
          read_process_output(
            stdout_read,
            max_output_bytes,
            truncate_output,
            output_state,
            output_mutex,
            pid,
          )
        end
      stderr_thread =
        Thread.new do
          Thread.current.report_on_exception = false
          read_process_output(
            stderr_read,
            max_output_bytes,
            truncate_output,
            output_state,
            output_mutex,
            pid,
          )
        end
      status = wait_for_process(pid, timeout)

      [stdout_thread.value, stderr_thread.value, status, output_state[:truncated]]
    ensure
      [stdout_read, stdout_write, stderr_read, stderr_write].each do |io|
        io&.close unless io.closed?
      rescue IOError
      end
    end

    private_class_method def self.capture_with_landlock(
      command,
      read:,
      write:,
      execute:,
      timeout:,
      env:,
      unsetenv_others:,
      chdir:,
      connect_tcp:,
      bind_tcp:,
      rlimits:,
      seccomp_deny_network:,
      max_output_bytes:,
      truncate_output:
    )
      capture_process(
        command,
        timeout: timeout,
        env: env,
        unsetenv_others: unsetenv_others,
        chdir: chdir,
        rlimits: rlimits,
        seccomp_deny_network: seccomp_deny_network,
        max_output_bytes: max_output_bytes,
        truncate_output: truncate_output,
        before_exec: -> do
          ::Landlock.restrict!(
            read: existing_paths(read),
            write: existing_paths(write),
            execute: existing_paths(execute),
            connect_tcp: sandbox_connect_tcp_ports(connect_tcp),
            bind_tcp: bind_tcp,
            allow_all_known: true,
          )
        end,
      )
    end

    private_class_method def self.wait_for_process(pid, timeout)
      if timeout
        Timeout.timeout(timeout) { Process.wait2(pid).last }
      else
        Process.wait2(pid).last
      end
    rescue Timeout::Error
      terminate_process(pid)
      Process.wait2(pid).last
    end

    def self.read_process_output(
      io,
      max_output_bytes,
      truncate_output,
      output_state,
      output_mutex,
      pid
    )
      return io.read if max_output_bytes.nil?

      output = +""
      while (chunk = io.read(READ_CHUNK_BYTES))
        chunk_to_append = chunk
        over_limit = false

        output_mutex.synchronize do
          remaining_bytes = max_output_bytes - output_state[:bytes]
          if remaining_bytes <= 0
            chunk_to_append = ""
            over_limit = true
          elsif chunk.bytesize > remaining_bytes
            chunk_to_append = chunk.byteslice(0, remaining_bytes)
            over_limit = true
          end

          output_state[:bytes] += chunk.bytesize
          output_state[:truncated] = true if over_limit
        end

        output << chunk_to_append
        if over_limit
          terminate_process(pid)
          if !truncate_output
            raise OutputTooLargeError, "Process output exceeded #{max_output_bytes} bytes"
          end
          break
        end
      end
      output
    end

    private_class_method :read_process_output

    private_class_method def self.terminate_process(pid)
      signal_process("TERM", pid)
      sleep 0.5
      signal_process("KILL", pid)
    end

    def self.signal_process(signal, pid)
      Process.kill(signal, -pid)
    rescue Errno::ESRCH
      begin
        Process.kill(signal, pid)
      rescue Errno::ESRCH
      end
    end

    private_class_method :signal_process
  end
end
