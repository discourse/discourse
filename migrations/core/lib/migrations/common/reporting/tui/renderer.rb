# frozen_string_literal: true

require "io/console"
require "unicode/display_width"

module Migrations
  module Reporting
    class Tui
      # The drawing half. It owns the step model and paints each frame. Only the
      # render thread touches it. All time comes from `clock` and all output goes
      # to `output`; both can be injected in tests.
      class Renderer
        include Formatting

        SPINNER = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏].freeze
        SPINNER_RATE = 6 # spinner steps per second, separate from the draw rate
        TITLE_WIDTH = 16 # smallest width; grows to the longest title, up to MAX_TITLE_WIDTH
        MAX_TITLE_WIDTH = 40 # upper limit, so a long title can't push the columns off-screen
        TIME_WIDTH = 7 # fits "9:59:59"; the column grows for longer runs
        PERCENT_WIDTH = 4 # "100%"
        COUNT_WIDTH = 10 # fits "99,999,999" (8 digits with commas); larger counts grow it
        RATE_SMOOTHING = 0.1 # EMA weight for each throughput sample; lower = smoother
        RATE_AFTER_SECONDS = 0.5 # don't show a rate until the step has run this long
        ETA_AFTER_SECONDS = 1 # don't show an ETA until the step has run this long
        SHORT_STEP_SECONDS = 2 # skip the rate/ETA for steps expected to finish within this
        # Columns of a live row. ETA is left-aligned (it has its own "ETA " label);
        # the rest are right-aligned. A bold percent takes the place of a progress
        # bar: it lines up in columns, works for several steps at once, and avoids
        # block characters that don't look the same on every terminal. Concurrency
        # sits last so it can't shift the columns the collapsed (finished) rows share.
        COLUMNS = %i[percent count elapsed eta rate concurrency].freeze
        LEFT_ALIGNED = %i[eta].freeze

        Step =
          Struct.new(
            :title,
            :total,
            :current,
            :skip_count,
            :warning_count,
            :error_count,
            :state,
            :started_at,
            :finished_at,
            :rate,
            :rate_sampled_at,
            :rate_sampled_current,
            :concurrency,
            keyword_init: true,
          )

        def initialize(output: $stdout, width: nil, clock: nil, titles: [])
          @output = output
          @forced_width = width
          @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
          @terminal_columns = terminal_columns
          # NO_COLOR disables color only when set to a non-empty value.
          @color = ENV["NO_COLOR"].to_s.empty?
          # Translated once here, not every frame.
          @counting_label = I18n.t("progressbar.counting")
          @eta_label = I18n.t("progressbar.eta")
          @steps = {}
          @pending_permanent = []
          @live_count = 0
          @last_live = nil
          @resize_pending = false
          @finalizing = false
          @frame_buffer = +"" # reused on each repaint instead of making a new one
          # Reserve the column widths up front: a finished row scrolls into the
          # history and can't be realigned, so every column has to start at the
          # same place from the first row on. Percent is reserved on every row
          # (blank when finished) so finished and running totals share a column.
          @title_width = [
            [TITLE_WIDTH, *titles.map { |title| Ansi.width(title) }].max,
            MAX_TITLE_WIDTH,
          ].min
          @column_widths = {
            percent: PERCENT_WIDTH,
            count: COUNT_WIDTH,
            elapsed: TIME_WIDTH,
            eta: 0,
            rate: 0,
            concurrency: 0,
          }
        end

        # --- lifecycle (called by the render thread) ---

        def on_start
          emit(Ansi::HIDE_CURSOR)
          @output.flush
        end

        # Writes to the terminal. When NO_COLOR is set, it removes the color codes
        # (SGR) but keeps the cursor and erase codes.
        def emit(string)
          @output.write(@color ? string : string.gsub(Ansi::SGR, ""))
        end

        def mark_resize
          @resize_pending = true
        end

        def consume_resize
          return unless @resize_pending
          @resize_pending = false
          @terminal_columns = terminal_columns
          @last_live = nil # force a repaint at the new width
          return if @live_count == 0

          # After a resize the old region is still at least `@live_count` rows
          # tall (a rewrap can only make it taller, never shorter), so moving up
          # `@live_count - 1` rows keeps us inside our own rows. Erase to the end
          # of the screen and let the next repaint draw again at the new width.
          out = +""
          out << Ansi.cursor_up(@live_count - 1) if @live_count > 1
          out << "\r" << Ansi::ERASE_BELOW
          emit(out)
          @live_count = 0
        end

        # Mark any step that is still running as interrupted, remove the live
        # region, and restore the terminal. Safe to call more than once.
        def finalize
          return if @finalized
          @finalized = true
          @steps.each_value do |step|
            next unless running?(step)
            step.finished_at = now
            step.state = :interrupted
            @pending_permanent << collapsed_line(step)
          end
          repaint(final: true)
          emit(Ansi::SHOW_CURSOR)
          @output.flush
        end

        # --- model updates ---

        def apply(event)
          case event[0]
          when :start
            _, id, title = event
            @steps[id] = Step.new(
              title:,
              total: nil,
              current: 0,
              skip_count: 0,
              warning_count: 0,
              error_count: 0,
              state: :starting,
              started_at: now,
              finished_at: nil,
              rate: nil,
              rate_sampled_at: nil,
              rate_sampled_current: 0,
              concurrency: 1,
            )
          when :concurrency
            _, id, count = event
            step = @steps[id]
            step.concurrency = count if step
          when :progress_begin
            _, id, max_progress = event
            step = @steps[id]
            return unless step && running?(step)
            step.total = max_progress
            step.state = :running
            step.started_at = now # start timing the work, not the counting before it
            step.rate_sampled_at = now
            step.rate_sampled_current = step.current
          when :progress
            _, id, current, skip_count, warning_count, error_count = event
            step = @steps[id]
            return unless step && step.state == :running
            step.current = current
            step.skip_count = skip_count
            step.warning_count = warning_count
            step.error_count = error_count
          when :notice
            _, id, message = event
            step = @steps[id]
            notice_lines(step && step.title, message).each { |line| @pending_permanent << line }
          when :finish
            _, id, outcome = event
            step = @steps.delete(id) # no longer needed; its line is permanent now
            return unless step
            step.finished_at = now
            step.state = outcome # :done, :interrupted, or :failed
            @pending_permanent << collapsed_line(step)
          when :finalizing_begin
            @finalizing = true
          when :finalizing_end
            @finalizing = false
          when :summary
            _, runtime, total, failed, skipped = event
            @pending_permanent << summary_line(runtime, total, failed, skipped)
          end
        end

        # --- rendering ---

        # Between frames the cursor rests at column 0 of the last live line. Each
        # frame: move up to the top of the region, print any new permanent lines
        # (these push the region down and scroll into the history), redraw the live
        # lines, then erase leftover lines if the region got shorter. Erasing the
        # whole line on every redraw removes old characters and clears wrap flags. A
        # frame that is the same as the last one is skipped.
        def repaint(final: false)
          permanent = @pending_permanent
          @pending_permanent = []
          live = final ? [] : format_live(running_steps)
          live += [finalizing_line] if @finalizing && !final

          return if permanent.empty? && live.empty? && @live_count == 0
          return if !final && permanent.empty? && live == @last_live

          out = @frame_buffer.clear
          out << Ansi.cursor_up(@live_count - 1) if @live_count > 1
          out << "\r"

          permanent.each { |line| out << Ansi::ERASE_LINE << fit_to_width(line) << "\r\n" }

          live.each_with_index do |line, index|
            out << Ansi::ERASE_LINE << fit_to_width(line)
            out << "\r\n" if index < live.size - 1
          end

          # The permanent lines printed this frame already overwrote that many
          # rows of the old live region, so only the rows past both the new live
          # lines and those permanents are still stale and need erasing.
          leftover = [@live_count - permanent.size - live.size, 0].max
          if leftover > 0
            leftover.times { out << "\r\n" << Ansi::ERASE_LINE }
            out << Ansi.cursor_up(leftover) unless final
          end
          out << "\r"

          emit(out)
          @output.flush
          @live_count = live.size
          @last_live = live
        end

        private

        def now
          @clock.call
        end

        def running?(step)
          %i[starting running].include?(step.state)
        end

        def running_steps
          @steps.values.select { |step| running?(step) }
        end

        # Keep lines two columns short of the window width. While the window is
        # being dragged, WINCH arrives in small steps; lines that never reach the
        # new width never wrap, so the resize cleanup stays exact. Staying under the
        # width also avoids the wrap glitch in the last column.
        def fit_to_width(line)
          Ansi.truncate(line, [@terminal_columns - 2, 8].max)
        end

        def format_live(steps)
          return [] if steps.empty?
          rows = steps.map { |step| row_fields(step) }
          widths = reserve_column_widths(rows)
          glyph = spinner # animated; same frame for every live row
          rows.zip(widths).map { |row, row_widths| build_live_line(row, row_widths, glyph) }
        end

        # Measure each cell once and grow the reserved column widths to fit.
        # Returns the per-cell widths so the padding can reuse them instead of
        # stripping SGR a second time.
        def reserve_column_widths(rows)
          widths = rows.map { |row| COLUMNS.map { |column| Ansi.width(row[column]) } }
          COLUMNS.each_with_index do |column, i|
            @column_widths[column] = [
              @column_widths[column],
              *widths.map { |row_widths| row_widths[i] },
            ].max
          end
          widths
        end

        def build_live_line(row, row_widths, glyph)
          cells =
            COLUMNS.each_with_index.filter_map do |column, i|
              next if @column_widths[column] == 0
              align = LEFT_ALIGNED.include?(column) ? :left : :right
              Ansi.pad_to(row[column], row_widths[i], @column_widths[column], align)
            end
          line = +"#{glyph} #{title_field(row[:title])}  "
          line << cells.join("  ")
          line << row[:annot] unless row[:annot].empty?
          line
        end

        # Builds one running step as a hash of column strings (blank where a
        # column doesn't apply). The spinner in front shows it's alive (added in
        # format_live). The bold percent and the total stand in for a progress bar;
        # the count column shows the total (not current/max), because the percent
        # already shows how far along it is. The extra numbers (elapsed, ETA, rate)
        # are dimmed.
        def row_fields(step)
          elapsed = now - step.started_at
          fields = {
            title: step.title,
            percent: "",
            count: "",
            elapsed: "",
            eta: "",
            rate: "",
            concurrency: concurrency_cell(step.concurrency),
            annot: "",
          }

          if step.state == :starting # work hasn't started: no total yet
            fields[:count] = "#{Ansi::DIM}#{@counting_label}#{Ansi::RESET}"
            fields[:elapsed] = "#{Ansi::DIM}#{format_duration(elapsed)}#{Ansi::RESET}"
            return fields
          end

          sample_rate(step)
          remaining = remaining_seconds(step)
          # Skip the rate and ETA for a step that's about to finish anyway — noise.
          short = remaining && elapsed + remaining < SHORT_STEP_SECONDS

          if step.total&.positive?
            fraction = [step.current.to_f / step.total, 1.0].min
            fields[:percent] = "#{Ansi::BOLD}#{format("%3.0f%%", fraction * 100)}#{Ansi::RESET}"
            fields[:count] = format_count(step.total)
            if remaining && elapsed > ETA_AFTER_SECONDS && !short
              fields[:eta] = "#{Ansi::DIM}#{@eta_label} #{format_duration(remaining)}#{Ansi::RESET}"
            end
          else # unknown or empty total: no percent, just the running count
            fields[:count] = format_count(step.current)
          end

          fields[:elapsed] = "#{Ansi::DIM}#{format_duration(elapsed)}#{Ansi::RESET}"
          if step.rate && elapsed > RATE_AFTER_SECONDS && !short
            rate = step.rate < 1 ? "<1" : format_count(step.rate.round)
            fields[:rate] = "#{Ansi::DIM}#{rate}/s#{Ansi::RESET}"
          end
          fields[:annot] = annotations(step)
          fields
        end

        # Smoothed items/s, sampled each frame the count advances and folded into
        # an EMA, so the rate (and ETA) track recent throughput, not the run-long
        # average.
        def sample_rate(step)
          t = now
          window = t - step.rate_sampled_at
          return if window <= 0 || step.current == step.rate_sampled_current

          per_second = (step.current - step.rate_sampled_current) / window
          step.rate =
            if step.rate
              per_second * RATE_SMOOTHING + step.rate * (1 - RATE_SMOOTHING)
            else
              per_second
            end
          step.rate_sampled_at = t
          step.rate_sampled_current = step.current
        end

        # Estimated seconds until the step finishes, or nil if we can't tell yet
        # (no total, or no rate sampled).
        def remaining_seconds(step)
          return unless step.total&.positive? && step.rate
          [(step.total - step.current) / step.rate, 0].max
        end

        # Builds the permanent line for a finished, interrupted, or failed step: a
        # status glyph, a blank percent column (so the count lines up with the live
        # rows' totals), the count, the duration, and a short note at the end for
        # the outcomes that aren't clean.
        def collapsed_line(step)
          duration = (step.finished_at || now) - step.started_at
          count = step.state == :done ? (step.total || step.current) : step.current

          line = +"#{status_glyph(step)} #{title_field(step.title)}  "
          line << padded_columns(format_count(count), duration, dim: true)
          line << outcome_note(step)
          line << annotations(step)
          line
        end

        # The transient live line shown while the run finishes background work
        # (merging shards) after every step is done. The spinner animates it.
        def finalizing_line
          "#{spinner} #{Ansi::DIM}#{I18n.t("progressbar.finishing_up")}#{Ansi::RESET}"
        end

        # The permanent end-of-run line: a Σ, the total runtime in the elapsed
        # column (so it lines up under the per-step durations), and the step tally.
        def summary_line(runtime, total, failed, skipped)
          columns = padded_columns("", runtime, dim: false)
          line = +"#{Ansi::BOLD}Σ#{Ansi::RESET} #{title_field(I18n.t("progressbar.total"))}  "
          line << columns << summary_tally(total, failed, skipped)
          line
        end

        def summary_tally(total, failed, skipped)
          note = +"  #{I18n.t("progressbar.steps", count: total, number: total)}"
          if failed > 0
            note << "  #{Ansi::RED}#{I18n.t("progressbar.steps_failed", number: failed)}#{Ansi::RESET}"
          end
          if skipped > 0
            note << "  #{Ansi::YELLOW}#{I18n.t("progressbar.steps_skipped", number: skipped)}#{Ansi::RESET}"
          end
          note
        end

        def status_glyph(step)
          case step.state
          when :done
            "#{Ansi::GREEN}✓#{Ansi::RESET}"
          when :failed
            "#{Ansi::RED}✗#{Ansi::RESET}"
          else # :interrupted — no glyph; the note says what happened
            " "
          end
        end

        def outcome_note(step)
          case step.state
          when :failed
            "  #{Ansi::RED}#{I18n.t("progressbar.failed")}#{Ansi::RESET}"
          when :interrupted
            if step.total&.positive?
              percent = [(step.current.to_f / step.total * 100).round, 100].min
              "  #{Ansi::YELLOW}#{I18n.t("progressbar.interrupted_at", percent:)}#{Ansi::RESET}"
            else
              "  #{Ansi::YELLOW}#{I18n.t("progressbar.interrupted")}#{Ansi::RESET}"
            end
          else
            ""
          end
        end

        # The blank-percent, count, and time triple shared by the finished rows
        # and the run summary. It uses the same widths as the live rows, so every
        # count and duration lines up down the whole display. The percent is
        # always blank here; a finished row dims its duration, the summary doesn't.
        def padded_columns(count, duration, dim:)
          time = Ansi.pad(format_duration(duration), @column_widths[:elapsed], :right)
          time = "#{Ansi::DIM}#{time}#{Ansi::RESET}" if dim
          [
            Ansi.pad("", @column_widths[:percent]),
            Ansi.pad(count, @column_widths[:count], :right),
            time,
          ].join("  ")
        end

        # A notice becomes one or more permanent lines. A message may carry
        # newlines (exception messages built by `failure_notice` often do); an
        # embedded "\n" has zero display width, so it would slip through
        # `fit_to_width` and move the cursor a row the live-region math doesn't
        # account for, fusing rows and stranding stale ones. Split it so each
        # source line is its own permanent line: the first keeps the title
        # prefix, the rest are indented so a backtrace-style message reads as one
        # block. The title is deliberately not padded to the table's title column
        # (unlike the step rows): a notice is prose, not a table row.
        def notice_lines(title, message)
          lines = message.to_s.split("\n").map(&:rstrip).reject(&:empty?)
          lines = [""] if lines.empty?
          prefix = title ? "#{title}  " : ""

          lines.each_with_index.map do |text, index|
            head = index == 0 ? prefix : "  " # continuation lines just indent
            "#{head}#{Ansi::DIM}#{text}#{Ansi::RESET}"
          end
        end

        # The skip, warning, and error labels, shown only when the count is above
        # 0, using the shared `progressbar.*` translations. Each one has its own
        # glyph, not just a color, so it can be read without seeing color. The
        # error glyph is ⊗, not the status ✗, so the two don't look alike.
        def annotations(step)
          return "" if step.skip_count == 0 && step.warning_count == 0 && step.error_count == 0

          out = +""
          if step.skip_count > 0
            out << "  #{Ansi::CYAN}⊘ #{count_label(:skips, step.skip_count)}#{Ansi::RESET}"
          end
          if step.warning_count > 0
            out << "  #{Ansi::YELLOW}⚠ #{count_label(:warnings, step.warning_count)}#{Ansi::RESET}"
          end
          if step.error_count > 0
            out << "  #{Ansi::RED}⊗ #{count_label(:errors, step.error_count)}#{Ansi::RESET}"
          end
          out
        end

        # The title comes after the status glyph, padded to the reserved width so
        # the columns after it line up across rows (each caller adds a "  "
        # separator).
        def title_field(title)
          Ansi.pad(ellipsize(title, @title_width), @title_width, :left)
        end

        # Shortens a title to fit `max` display columns, ending it with "…". Titles
        # are plain text, so we can step through them character by character.
        def ellipsize(title, max)
          return title if Ansi.width(title) <= max

          out = +""
          used = 0
          title.each_grapheme_cluster do |cluster|
            w = Unicode::DisplayWidth.of(cluster)
            break if used + w > max - 1 # leave a cell for the ellipsis
            out << cluster
            used += w
          end
          "#{out}…"
        end

        def spinner
          SPINNER[(now * SPINNER_RATE).to_i % SPINNER.size]
        end

        def concurrency_cell(count)
          return "" if count <= 1

          # `emit` strips the SGR when color is off, like every other cell.
          "#{Ansi::MAGENTA}#{count}×#{Ansi::RESET}"
        end

        def terminal_columns
          @forced_width || @output.winsize[1]
        rescue StandardError
          80
        end
      end
    end
  end
end
