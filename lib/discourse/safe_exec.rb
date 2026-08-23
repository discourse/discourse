# frozen_string_literal: true

require "landlock"

module Discourse
  class SafeExec
    DEFAULT_READ_PATHS = %w[/bin /lib /lib64 /usr].freeze
    DEFAULT_EXECUTE_PATHS = %w[/bin /lib /lib64 /usr].freeze

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
      bind_tcp: nil,
      rlimits: {},
      seccomp_deny_network: false,
      max_output_bytes: nil,
      truncate_output: false
    )
      if ::Landlock.supported?
        result =
          ::Landlock.capture(
            command,
            read: read,
            write: write,
            execute: execute,
            timeout: timeout,
            failure_message: failure_message,
            success_status_codes: success_status_codes,
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

        return result.stdout if result.output_truncated? && truncate_output

        if !result.status.exited? || !success_status_codes.include?(result.status.exitstatus)
          raise_command_error(command, failure_message, result)
        end

        result.stdout
      else
        fallback_command = env ? [env, *command] : command
        Discourse::Utils.execute_command(
          *fallback_command,
          timeout: timeout,
          failure_message: failure_message,
          success_status_codes: success_status_codes,
          chdir: chdir || ".",
          unsetenv_others: unsetenv_others,
        )
      end
    rescue ::Landlock::CommandError => e
      raise Discourse::Utils::CommandError.new(
              e.message,
              stdout: e.stdout,
              stderr: e.stderr,
              status: e.status,
            )
    end

    def self.landlock_supported?
      ::Landlock.supported?
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

    def self.raise_command_error(command, failure_message, result)
      message =
        [command.join(" "), failure_message, result.stderr].filter { |part| part.to_s != "" }
          .join("\n")
      raise Discourse::Utils::CommandError.new(
              message,
              stdout: result.stdout,
              stderr: result.stderr,
              status: result.status,
            )
    end
    private_class_method :raise_command_error
  end
end
