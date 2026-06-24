# frozen_string_literal: true

begin
  require "landlock"
rescue LoadError
end

module Discourse
  class SafeExec
    DEFAULT_READ_PATHS = %w[/bin /etc /lib /lib64 /usr].freeze
    DEFAULT_EXECUTE_PATHS = %w[/bin /lib /lib64 /usr].freeze
    LANDLOCK_COMMAND_ERROR =
      if defined?(::Landlock::CommandError)
        ::Landlock::CommandError
      else
        Class.new(StandardError)
      end
    LANDLOCK_UNSUPPORTED_ERROR =
      if defined?(::Landlock::UnsupportedError)
        ::Landlock::UnsupportedError
      else
        Class.new(StandardError)
      end

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
      command = normalize_command(command)

      if landlock_supported?
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
            connect_tcp: connect_tcp || [],
            bind_tcp: bind_tcp,
            rlimits: rlimits,
            seccomp_deny_network: seccomp_deny_network,
            max_output_bytes: max_output_bytes,
            truncate_output: truncate_output,
            allow_all_known: filesystem_restriction?(read, write, execute),
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
        )
      end
    rescue LANDLOCK_COMMAND_ERROR, LANDLOCK_UNSUPPORTED_ERROR => e
      raise Discourse::Utils::CommandError.new(
              e.message,
              stdout: e.respond_to?(:stdout) ? e.stdout : nil,
              stderr: e.respond_to?(:stderr) ? e.stderr : nil,
              status: e.respond_to?(:status) ? e.status : nil,
            )
    end

    def self.landlock_supported?
      defined?(::Landlock) && ::Landlock.supported?
    end

    def self.default_read_paths
      existing_paths(DEFAULT_READ_PATHS)
    end

    def self.default_execute_paths
      existing_paths(DEFAULT_EXECUTE_PATHS)
    end

    def self.normalize_command(command)
      command.length == 1 && command.first.is_a?(Array) ? command.first : command
    end

    def self.filesystem_restriction?(read, write, execute)
      Array(read).any? || Array(write).any? || Array(execute).any?
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
