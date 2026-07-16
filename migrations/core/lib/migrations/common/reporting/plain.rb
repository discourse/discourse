# frozen_string_literal: true

module Migrations
  module Reporting
    # Line-based reporting for pipes, CI logs, and dumb terminals — anywhere
    # {Tui} can't run ({Factory} decides). It never moves the cursor and has no
    # live region. It prints one line when a step starts and one when it
    # finishes, one line as progress advances (every 10% by default; or, when the
    # total is unknown, one every few seconds), and notices as they come. It only writes whole
    # lines, behind a mutex, so two threads can't mix half-written lines together.
    class Plain < Reporter
      include Formatting

      HEARTBEAT_SECONDS = 5 # how often to print progress when the total is unknown
      PROGRESS_LOG_INTERVAL = 10 # print a progress line every N percent

      Step =
        Struct.new(
          :title,
          :started_at,
          :total,
          :current,
          :logged_percent,
          :last_heartbeat,
          :skip_count,
          :warning_count,
          :error_count,
          keyword_init: true,
        )

      def initialize(output: $stdout, clock: nil)
        super()
        @output = output
        @output.sync = true if @output.respond_to?(:sync=)
        @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        @steps = {}
        @mutex = Mutex.new
      end

      def report_start(id, title)
        @mutex.synchronize do
          now = monotonic
          @steps[id] = Step.new(
            title:,
            started_at: now,
            total: nil,
            current: 0,
            logged_percent: 0,
            last_heartbeat: now,
            skip_count: 0,
            warning_count: 0,
            error_count: 0,
          )
          @output.puts(title)
        end
      end

      def report_notice(id, message)
        @mutex.synchronize do
          step = @steps[id]
          @output.puts("    #{step.title} #{message}") if step
        end
      end

      def report_progress_begin(id, max_progress)
        @mutex.synchronize { @steps[id].total = max_progress if @steps[id] }
      end

      def report_concurrency(_id, _count)
        # No-op: the plain log skips the live fork/CPU count.
      end

      def report_progress(id, current, skip_count, warning_count, error_count)
        @mutex.synchronize do
          step = @steps[id]
          next unless step

          step.current = current
          step.skip_count = skip_count
          step.warning_count = warning_count
          step.error_count = error_count

          if step.total&.positive?
            log_progress(step, current)
          else
            log_heartbeat(step, current)
          end
        end
      end

      def report_finish(id, outcome)
        @mutex.synchronize do
          step = @steps[id]
          next unless step

          count = outcome == :done ? step.total || step.current : step.current
          line = +"#{finish_glyph(outcome)} #{step.title}"
          line << " #{format_count(count)}" if count > 0
          line << " (#{format_duration(monotonic - step.started_at)})"
          line << " — #{I18n.t("progressbar.#{outcome}")}" unless outcome == :done
          line << annotations(step)
          @output.puts(line)
        end
      end

      def report_finalizing_begin
        @mutex.synchronize { @output.puts(I18n.t("progressbar.finishing_up")) }
      end

      def report_summary(runtime:, total:, failed:, skipped:)
        tally = [I18n.t("progressbar.steps", count: total, number: total)]
        tally << I18n.t("progressbar.steps_failed", number: failed) if failed > 0
        tally << I18n.t("progressbar.steps_skipped", number: skipped) if skipped > 0
        @mutex.synchronize do
          @output.puts(
            "#{I18n.t("progressbar.total")}: #{tally.join(", ")} (#{format_duration(runtime)})",
          )
        end
      end

      def close
        # nothing to free — we write plain lines and keep nothing open
      end

      private

      def log_progress(step, current)
        percent = [current * 100 / step.total, 100].min
        milestone = percent - percent % PROGRESS_LOG_INTERVAL
        return if milestone <= step.logged_percent

        step.logged_percent = milestone
        @output.puts(
          "    #{step.title} #{milestone}% (#{format_count(current)}/#{format_count(step.total)})" \
            "#{annotations(step)}",
        )
      end

      def log_heartbeat(step, current)
        now = monotonic
        return if now - step.last_heartbeat < HEARTBEAT_SECONDS

        step.last_heartbeat = now
        @output.puts(
          "    #{step.title} #{format_count(current)} #{I18n.t("progressbar.processed")}#{annotations(step)}",
        )
      end

      def finish_glyph(outcome)
        case outcome
        when :failed
          "✗"
        when :interrupted
          "⚠"
        else
          "✓"
        end
      end

      def annotations(step)
        parts = []
        parts << count_label(:skips, step.skip_count) if step.skip_count > 0
        parts << count_label(:warnings, step.warning_count) if step.warning_count > 0
        parts << count_label(:errors, step.error_count) if step.error_count > 0
        parts.empty? ? "" : " — #{parts.join(", ")}"
      end

      def monotonic
        @clock.call
      end
    end
  end
end
