# frozen_string_literal: true

require "colored2"
require "ruby-progressbar"

module Migrations
  class ExtendedProgressBar
    def initialize(max_progress: nil)
      @max_progress = max_progress

      @skip_count = 0
      @warning_count = 0
      @error_count = 0
      @extra_information = +""

      @base_format = nil
      @progressbar = nil
    end

    def run
      raise "ProgressBar already started" if @progressbar

      format = calculate_format
      setup_progressbar

      yield self

      finalize_progressbar(format)

      nil
    end

    def update(increment_by:, skip_count: 0, warning_count: 0, error_count: 0)
      updated = false

      if skip_count > 0
        @skip_count += skip_count
        updated = true
      end

      if warning_count > 0
        @warning_count += warning_count
        updated = true
      end

      if error_count > 0
        @error_count += error_count
        updated = true
      end

      update_format if updated

      if increment_by == 1
        @progressbar.increment
      else
        @progressbar.progress += increment_by
      end
    end

    private

    def calculate_format
      if @max_progress
        format = I18n.t("progressbar.processed.progress_with_max", current: "%c", max: "%C")
        @base_format = "    %a | %E | #{format}"
      else
        format = I18n.t("progressbar.processed.progress", current: "%c")
        @base_format = "    %a | #{format}"
      end

      format
    end

    def setup_progressbar
      @progressbar =
        ::ProgressBar.create(
          total: @max_progress,
          autofinish: false,
          projector: {
            type: "smoothing",
            strength: 0.5,
          },
          format: @base_format,
          throttle_rate: 0.5,
        )
    end

    def update_format
      @extra_information.clear

      messages = []
      messages << I18n.t("progressbar.skips", count: @skip_count).cyan if @skip_count > 0
      messages << I18n.t("progressbar.warnings", count: @warning_count).yellow if @warning_count > 0
      messages << I18n.t("progressbar.errors", count: @error_count).red if @error_count > 0

      @extra_information << " | #{messages.join(" | ")}" unless messages.empty?
      @progressbar.format = "#{@base_format}#{@extra_information}"
    end

    def finalize_progressbar(format)
      print "\033[K" # delete the output of progressbar, because it doesn't overwrite longer lines
      @progressbar.format = "    %a | #{format}#{@extra_information}"
      @progressbar.finish
    end
  end
end

class ProgressBar
  module Components
    class Time
      def estimated_with_label(out_of_bounds_time_format = nil)
        I18n.t("progressbar.estimated", duration: estimated(out_of_bounds_time_format))
      end

      def elapsed_with_label
        I18n.t("progressbar.elapsed", duration: elapsed)
      end
    end
  end
end
