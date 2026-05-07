# frozen_string_literal: true

require "discourse/safe_exec"

module DiscourseAi
  module Completions
    class DocToText
      ANTIWORD_TIMEOUT_SECONDS = 5
      MAX_CONVERSION_OUTPUT_BYTES = 4 * 100_001
      SAFE_EXEC_ENV = { "PATH" => ENV["PATH"].to_s }.freeze
      ANTIWORD_RLIMITS = {
        cpu_seconds: ANTIWORD_TIMEOUT_SECONDS,
        memory_bytes: 256 * 1024 * 1024,
        file_size_bytes: 1 * 1024 * 1024,
        open_files: 64,
        processes: 0,
      }

      def self.convert(path)
        return if !antiword_installed?

        Discourse::SafeExec.capture(
          "antiword",
          "-w",
          "0",
          path,
          read: sandbox_read_paths(path),
          execute: Discourse::SafeExec.default_execute_paths,
          timeout: ANTIWORD_TIMEOUT_SECONDS,
          env: SAFE_EXEC_ENV,
          unsetenv_others: true,
          rlimits: ANTIWORD_RLIMITS,
          seccomp_deny_network: true,
          max_output_bytes: MAX_CONVERSION_OUTPUT_BYTES,
          truncate_output: true,
          failure_message: "Failed to convert .doc upload to text",
        )
      end

      def self.antiword_installed?
        return @antiword_installed if defined?(@antiword_installed)

        @antiword_installed =
          begin
            Discourse::Utils.execute_command("which", "antiword")
            true
          rescue Discourse::Utils::CommandError
            false
          end
      end

      def self.sandbox_read_paths(path)
        Discourse::SafeExec.default_read_paths + [File.realpath(path)]
      end
    end
  end
end
