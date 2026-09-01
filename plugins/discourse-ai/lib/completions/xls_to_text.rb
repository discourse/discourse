# frozen_string_literal: true

require "discourse/safe_exec"

module DiscourseAi
  module Completions
    class XlsToText
      XLS2CSV_TIMEOUT_SECONDS = 5
      MAX_CONVERSION_OUTPUT_BYTES = 4 * TextNormalization::MAX_EXTRACTED_TEXT_CHARS
      SAFE_EXEC_ENV = { "PATH" => ENV["PATH"].to_s }.freeze
      XLS2CSV_RLIMITS = {
        cpu_seconds: XLS2CSV_TIMEOUT_SECONDS,
        memory_bytes: 256 * 1024 * 1024,
        file_size_bytes: 1 * 1024 * 1024,
        open_files: 64,
        processes: 0,
      }

      CATDOC_CONFIG_PATH = "/etc/catdocrc"
      class << self
        def convert(path)
          return if !xls2csv_installed?

          Discourse::SafeExec.capture(
            "xls2csv",
            path,
            read: sandbox_read_paths(path),
            execute: Discourse::SafeExec.default_execute_paths,
            timeout: XLS2CSV_TIMEOUT_SECONDS,
            env: SAFE_EXEC_ENV,
            unsetenv_others: true,
            rlimits: XLS2CSV_RLIMITS,
            seccomp_deny_network: true,
            max_output_bytes: MAX_CONVERSION_OUTPUT_BYTES,
            truncate_output: true,
            failure_message: "Failed to convert .xls upload to text",
          )
        end

        def xls2csv_installed?
          return @xls2csv_installed if defined?(@xls2csv_installed)

          @xls2csv_installed =
            begin
              Discourse::Utils.execute_command("which", "xls2csv")
              true
            rescue Discourse::Utils::CommandError
              false
            end
        end
      end

      class << self
        def sandbox_read_paths(path)
          Discourse::SafeExec.default_read_paths +
            Discourse::SafeExec.existing_paths([CATDOC_CONFIG_PATH]) + [File.realpath(path)]
        end
      end
    end
  end
end
