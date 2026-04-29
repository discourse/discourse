# frozen_string_literal: true

module DiscourseAi
  module Completions
    class XlsToText
      XLS2CSV_TIMEOUT_SECONDS = 5

      def self.convert(path)
        return if !xls2csv_installed?

        Discourse::Utils.execute_command(
          "xls2csv",
          path,
          timeout: XLS2CSV_TIMEOUT_SECONDS,
          failure_message: "Failed to convert .xls upload to text",
        )
      end

      def self.xls2csv_installed?
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
  end
end
