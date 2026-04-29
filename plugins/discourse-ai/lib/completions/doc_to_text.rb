# frozen_string_literal: true

module DiscourseAi
  module Completions
    class DocToText
      ANTIWORD_TIMEOUT_SECONDS = 5

      def self.convert(path)
        return if !antiword_installed?

        Discourse::Utils.execute_command(
          "antiword",
          "-w",
          "0",
          path,
          timeout: ANTIWORD_TIMEOUT_SECONDS,
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
    end
  end
end
