# frozen_string_literal: true

require "landlock"

module Landlock
  class << self
    def capture_fork(
      read: nil,
      write: nil,
      execute: nil,
      connect_tcp: nil,
      bind_tcp: nil,
      paths: nil,
      scope: nil,
      chdir: nil,
      env: nil,
      unsetenv_others: false,
      close_others: true,
      allow_all_known: false,
      allow_unsupported: false,
      timeout: nil,
      stdin: nil,
      rlimits: {},
      seccomp_deny_network: false,
      max_output_bytes: nil,
      truncate_output: false,
      &block
    )
      raise ArgumentError, "capture_fork requires a block" if !block

      supported = supported?
      raise UnsupportedError, "Linux Landlock is unavailable" if !supported && !allow_unsupported

      max_output_bytes = Validation.validate_output_limit!(max_output_bytes)
      timeout = Validation.validate_timeout!(timeout)
      normalized_rlimits = Rlimits.normalize(rlimits)
      normalized_env = Env.normalize(env)
      policy =
        if supported
          Execution.prepare_policy(
            read:,
            write:,
            execute:,
            connect_tcp:,
            bind_tcp:,
            paths:,
            scope:,
            chdir:,
            allow_all_known:,
          )
        else
          { read:, write:, execute:, connect_tcp:, bind_tcp:, paths:, scope:, allow_all_known: }
        end

      if supported
        Execution.validate_capture_restriction!(
          **policy,
          seccomp_deny_network:,
          rlimits: normalized_rlimits,
        )
      end

      capture_fork_child(
        **policy,
        chdir:,
        env: normalized_env,
        unsetenv_others:,
        close_others:,
        timeout:,
        stdin:,
        rlimits: normalized_rlimits,
        seccomp_deny_network: supported && seccomp_deny_network,
        max_output_bytes:,
        truncate_output:,
        &block
      )
    rescue OutputTooLargeError => error
      result = error.result
      raise CommandError.new(
              error.message,
              stdout: result&.stdout.to_s,
              stderr: result&.stderr.to_s,
              status: result&.status,
              result:,
            )
    end

    private

    def capture_fork_child(
      read:,
      write:,
      execute:,
      connect_tcp:,
      bind_tcp:,
      paths:,
      scope:,
      allow_all_known:,
      chdir:,
      env:,
      unsetenv_others:,
      close_others:,
      timeout:,
      stdin:,
      rlimits:,
      seccomp_deny_network:,
      max_output_bytes:,
      truncate_output:,
      &block
    )
      stdout_reader, stdout_writer = IO.pipe
      stderr_reader, stderr_writer = IO.pipe
      stdin_reader, stdin_writer = IO.pipe

      pid =
        fork do
          stdout_reader.close
          stderr_reader.close
          stdin_writer.close
          Process.setpgrp
          STDIN.reopen(stdin_reader)
          STDOUT.reopen(stdout_writer)
          STDERR.reopen(stderr_writer)
          STDOUT.sync = true
          STDERR.sync = true
          stdin_reader.close
          stdout_writer.close
          stderr_writer.close

          close_inherited_ios if close_others
          Dir.public_send(:chdir, chdir) if chdir
          apply_capture_fork_environment(env, unsetenv_others:)
          if Policy.requested?(
               read:,
               write:,
               execute:,
               connect_tcp:,
               bind_tcp:,
               paths:,
               scope:,
               allow_all_known:,
             ) && supported?
            restrict!(
              read:,
              write:,
              execute:,
              connect_tcp:,
              bind_tcp:,
              paths:,
              scope:,
              allow_all_known:,
            )
          end
          Native.seccomp_deny_network! if seccomp_deny_network
          Rlimits.apply!(rlimits)
          block.call
          exit! 0
        rescue Exception => error
          warn "#{error.class}: #{error.message}"
          exit! 1
        end

      stdin_reader.close
      stdout_writer.close
      stderr_writer.close

      ProcessIO.complete_pipe_capture(
        pid,
        stdout_reader,
        stderr_reader,
        stdin_writer,
        stdin,
        timeout,
        max_output_bytes,
        truncate_output,
      )
    rescue OutputTooLargeError
      raise
    rescue Exception
      if pid
        ProcessIO.terminate_process(pid)
        ProcessIO.wait_for_pid(pid)
      end
      raise
    ensure
      [
        stdin_reader,
        stdin_writer,
        stdout_reader,
        stdout_writer,
        stderr_reader,
        stderr_writer,
      ].each do |io|
        io&.close unless io.closed?
      rescue IOError
      end
    end

    def apply_capture_fork_environment(env, unsetenv_others:)
      ENV.clear if unsetenv_others
      env&.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end

    def close_inherited_ios
      ObjectSpace
        .each_object(IO)
        .to_a
        .each do |io|
          next if io.closed? || io.fileno <= 2

          io.close
        rescue IOError
        end
    end
  end
end
