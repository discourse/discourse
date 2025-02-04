# frozen_string_literal: true

require "ruby-progressbar"

module Migrations
  class ExtendedProgressBar
    def initialize(max_progress: nil)
      @max_progress = max_progress

      @warning_count = 0
      @error_count = 0
      @extra_information = ""

      @base_format = nil
      @progressbar = nil
    end

    def run
      raise "ProgressBar already started" if @progressbar

      format = setup_progressbar
      yield self
      finalize_progressbar(format)

      nil
    end

    def update(progress, warning_count, error_count)
      extra_information_changed = false

      if warning_count > 0
        @warning_count += warning_count
        extra_information_changed = true
      end

      if error_count > 0
        @error_count += error_count
        extra_information_changed = true
      end

      if extra_information_changed
        @extra_information = +""

        if @warning_count > 0
          @extra_information << " | " <<
            I18n.t("progressbar.warnings", count: @warning_count).yellow
        end

        if @error_count > 0
          @extra_information << " | " << I18n.t("progressbar.errors", count: @error_count).red
        end

        @progressbar.format = "#{@base_format}#{@extra_information}"
      end

      if progress == 1
        @progressbar.increment
      else
        @progressbar.progress += progress
      end
    end

    private

    def setup_progressbar
      format =
        if @max_progress
          I18n.t("progressbar.processed.progress_with_max", current: "%c", max: "%C")
        else
          I18n.t("progressbar.processed.progress", current: "%c")
        end

      @base_format = @max_progress ? "    %a |%E | #{format}" : "    %a | #{format}"

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

      format
    end

    def finalize_progressbar(format)
      print "\033[K" # delete the output of progressbar, because it doesn't overwrite longer lines
      final_format = @max_progress ? "    %a | #{format}" : "    %a | #{format}"
      @progressbar.format = "#{final_format}#{@extra_information}"
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
