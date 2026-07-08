# frozen_string_literal: true

module Migrations
  module Conversion
    # Raised at the end of a run when one or more steps failed or were skipped, or
    # a shard merge failed. The converter logs per-item errors and keeps going, so
    # this is the single signal the CLI turns into a non-zero exit; its message is
    # the run summary shown to the user (no backtrace).
    #
    # The scheduler hands it the raw outcomes; the human-facing summary — and its
    # translations — are built here, where the message belongs.
    class ConvertError < StandardError
      include CLI::PresentableError

      # @param failures [Hash{Class<Step> => StandardError, nil}] failed steps and
      #   the error each raised
      # @param skipped [Array<Class<Step>>] steps skipped because a dependency failed
      # @param merge_errors [Array<StandardError>] errors from merging shards
      def initialize(failures: {}, skipped: [], merge_errors: [])
        super(summary(failures, skipped, merge_errors))
      end

      private

      def summary(failures, skipped, merge_errors)
        lines = [I18n.t("converter.errors.header")]

        failures.each do |step_class, error|
          lines << "  • #{failure_line(step_class, error)}"
          Array(error&.backtrace).first(5).each { |frame| lines << "      #{frame}" }
        end

        skipped.each do |step_class|
          lines << "  • #{I18n.t("converter.errors.step_skipped", title: step_class.title)}"
        end

        merge_errors.each { |error| lines << "  • #{merge_line(error)}" }

        lines.join("\n")
      end

      def failure_line(step_class, error)
        I18n.t(
          "converter.errors.step_failed",
          title: step_class.title,
          error_class: error&.class,
          error_message: error&.message,
        )
      end

      def merge_line(error)
        I18n.t(
          "converter.errors.merge_failed",
          error_class: error.class,
          error_message: error.message,
        )
      end
    end
  end
end
