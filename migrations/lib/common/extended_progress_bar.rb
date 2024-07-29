# frozen_string_literal: true

module Migrations
  class ExtendedProgressBar
    # @step.class.report_progress_in_percent?
    # @step.class.use_custom_progress_increment?
    def initialize(
      max_progress = nil,
      report_progress_in_percent = false,
      use_custom_progress_increment = false
    )
      @max_progress = max_progress
      @report_progress_in_percent = report_progress_in_percent
      @use_custom_progress_increment = use_custom_progress_increment

      @warnings = 0
      @errors = 0
      @extra_information = ""

      @base_format = nil
      @progressbar = nil
    end

    def with_progressbar
      format =
        if @report_progress_in_percent
          "Processed: %J%"
        elsif @max_progress
          "Processed: %c / %C"
        else
          "Processed: %c"
        end

      @base_format = @max_progress ? "    %a |%E | #{format}" : "    %a | #{format}"

      @progressbar =
        ProgressBar.create(
          total: @max_progress,
          autofinish: false,
          projector: {
            type: "smoothing",
            strength: 0.5,
          },
          format: @base_format,
          throttle_rate: 0.5,
        )

      yield

      print "\033[K" # delete the output of progressbar, because it doesn't overwrite longer lines
      final_format = @max_progress ? "    %a | #{format}" : "    %a | #{format}"
      @progressbar.format = "#{final_format}#{@extra_information}"
      @progressbar.finish

      self
    end

    def update(stats)
      changed = false

      if stats.warning_count > 0
        @warnings += stats.warning_count
        changed = true
      end

      if stats.error_count > 0
        @errors += stats.error_count
        changed = true
      end

      if changed
        @extra_information = +""
        @extra_information << " | " << "#{@warnings} warnings".yellow if @warnings > 0
        @extra_information << " | " << ("#{@errors} errors").red if @errors > 0
        @progressbar.format = "#{@base_format}#{@extra_information}"
      end

      if use_custom_progress_increment
        @progressbar.progress += stats.progress
      else
        @progressbar.increment
      end
    end
  end
end
