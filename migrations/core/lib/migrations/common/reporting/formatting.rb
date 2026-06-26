# frozen_string_literal: true

require "active_support/number_helper"

module Migrations
  module Reporting
    # Formats counts and durations. Both reporters use it, so the TUI and the
    # plain output look the same.
    module Formatting
      def format_count(number)
        ActiveSupport::NumberHelper.number_to_delimited(number)
      end

      # Builds a count label with the right singular/plural form. `count` picks
      # the form; `number` is the same value already grouped, which the
      # translation inserts.
      def count_label(kind, count)
        I18n.t("progressbar.#{kind}", count:, number: format_count(count))
      end

      # Formats a duration as whole seconds, rounded up (so any real work shows at
      # least 0:01). Switches to H:MM:SS once it passes an hour.
      def format_duration(seconds)
        whole = seconds.ceil
        if whole >= 3600
          format("%d:%02d:%02d", whole / 3600, whole % 3600 / 60, whole % 60)
        else
          format("%d:%02d", whole / 60, whole % 60)
        end
      end
    end
  end
end
