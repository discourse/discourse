# frozen_string_literal: true

module DiscourseAi
  module Evals
    # Renders richer CLI output for eval runs: a compact progress bar followed by
    # a table summarizing each case across models/personas.
    class ConsoleFormatter
      PROGRESS_BAR_WIDTH = 28
      SAMPLE_WIDTH = 46
      MIN_CELL_WIDTH = 8
      DEFAULT_MAX_WIDTH = 120
      JUDGE_COLUMN_LABEL = "judge"

      def initialize(label:, output:, total_targets:, persona_key: nil)
        @run_label = label
        @output = output
        @total_targets = total_targets
        @persona_key = persona_key
        @rows = []
        @columns = []
        @completed_units = 0
        @total_units = nil
        @case_count = nil
        @row_offsets = {}
        @max_table_width = detect_max_width
      end

      def announce_start
        header = "Starting evaluation #{run_label}"
        header << " (persona: #{persona_key})" if persona_key && persona_key != "default"
        output.puts(header)
      end

      def record_result(display_label:, llm_label:, results:, raw_entries:, row_prefix: nil)
        register_column(display_label)
        @case_count = [@case_count, results.length].compact.max
        row_start = resolve_row_start(row_prefix)

        results.each_with_index do |result, index|
          row_index = row_start + index
          row =
            rows[row_index] ||= {
              label: label_for(result[:metadata], index, row_prefix),
              cells: {
              },
            }
          row[:cells][display_label] = build_cell(result, raw_entries&.[](index))
        end

        refresh_total_units
        bump_progress(results.length, llm_label)
      end

      def record_skip(display_label:, llm_label:, reason:, row_prefix: nil)
        register_column(display_label)
        @case_count = [@case_count, 1].compact.max
        row_start = resolve_row_start(row_prefix)

        row = rows[row_start] ||= { label: label_for({}, 0, row_prefix), cells: {} }
        row[:cells][display_label] = { status: :skipped, detail: reason }

        refresh_total_units
        bump_progress(@case_count, llm_label)
      end

      def record_comparison_judged(
        row_prefix:,
        candidates:,
        result:,
        judge_label: JUDGE_COLUMN_LABEL
      )
        row_indices = row_indices_for(row_prefix)
        @case_count = [@case_count, row_indices.length].compact.max

        register_comparison_columns(candidates)
        register_column(judge_label)

        row_indices.each_with_index do |row_index, offset|
          label_suffix = label_suffix_for_winner(result[:winner], result[:winner_label])
          ensure_row(row_index, row_prefix, offset, label_suffix: label_suffix)

          rows[row_index][:cells][judge_label] = judged_summary_cell(result)

          candidates.each_with_index do |candidate, idx|
            rows[row_index][:cells][candidate[:display_label]] = comparison_cell_for(
              candidate: candidate,
              result: result,
              candidate_index: idx,
            )
          end
        end

        refresh_total_units
      end

      def record_comparison_expected(row_prefix:, candidates:, winner:, failures:, status_line:)
        row_indices = row_indices_for(row_prefix)
        @case_count = [@case_count, row_indices.length].compact.max

        register_comparison_columns(candidates)
        failure_map = failures.index_by { |failure| normalize_label(failure[:label]) }
        tie = winner.to_s == "tie"

        row_indices.each_with_index do |row_index, offset|
          label_suffix = label_suffix_for_winner(winner, nil)
          ensure_row(row_index, row_prefix, offset, label_suffix: label_suffix)

          candidates.each do |candidate|
            candidate_label = normalize_label(candidate[:label])
            rows[row_index][:cells][candidate[:display_label]] = expected_comparison_cell(
              candidate_label: candidate_label,
              winner: normalize_label(winner),
              tie: tie,
              failure: failure_map[candidate_label],
              status_line: status_line,
              output: candidate[:output],
            )
          end
        end

        refresh_total_units
      end

      def finalize
        return if rows.empty?

        clear_progress_line if progress_active?
        output.puts
        output.puts(build_table)
        output.puts(summary_line)
        output.puts(legend_line)
      end

      def pause_progress_line
        clear_progress_line if progress_active?
      end

      private

      attr_reader :run_label, :output, :rows, :columns, :persona_key, :row_offsets

      def register_column(label)
        label = label.to_s
        columns << label if columns.exclude?(label)
      end

      def resolve_row_start(row_prefix)
        key = row_prefix || :default
        row_offsets[key] ||= rows.length
      end

      def row_indices_for(row_prefix)
        start_index = row_offsets[row_prefix] || resolve_row_start(row_prefix)
        next_start = row_offsets.values.select { |offset| offset > start_index }.min
        end_index = (next_start && next_start > 0) ? next_start - 1 : rows.length - 1
        end_index = start_index if end_index < start_index

        indices = (start_index..end_index).to_a
        indices = [start_index] if indices.empty?
        indices
      end

      def ensure_row(row_index, row_prefix, relative_index, label_suffix: nil)
        rows[row_index] ||= {
          label: label_for({}, relative_index, row_prefix, label_suffix: label_suffix),
          cells: {
          },
        }
      end

      def build_cell(result, raw_entry)
        status = normalize_status(result[:result])
        detail = detail_for(result, raw_entry)

        { status: status, detail: detail }
      end

      def normalize_status(value)
        case value
        when :pass
          :pass
        when :fail
          :fail
        when :skipped
          :skipped
        else
          :unknown
        end
      end

      def detail_for(result, raw_entry)
        return truncate(detail_for_skip(result), SAMPLE_WIDTH) if result[:result] == :skipped
        return nil if result[:result] == :pass

        if result[:result] == :fail
          expected = stringify(result[:expected_output] || result[:expected_output_regex])
          actual = stringify(result[:actual_output] || extract_raw(raw_entry))
          parts = []
          parts << "Expected: #{expected}" if expected.present?
          parts << "Actual: #{actual}" if actual.present?
          return truncate(parts.join(" | "), SAMPLE_WIDTH) if parts.any?
        end

        sample = stringify(result[:actual_output] || extract_raw(raw_entry))
        truncate(sample, SAMPLE_WIDTH) if sample.present?
      end

      def comparison_cell_for(candidate:, result:, candidate_index:)
        winner = normalize_label(result[:winner])
        ratings = Array(result[:ratings])
        rating_map = ratings.index_by { |rating| normalize_label(rating[:candidate]) }
        rating = rating_map[normalize_label(candidate[:label])] || ratings[candidate_index]
        tie = tie_result?(winner, result[:winner_label])
        status =
          if tie
            :pass
          elsif winner.present?
            normalize_label(candidate[:label]) == winner ? :pass : :fail
          else
            :unknown
          end

        detail =
          comparison_detail(
            rating: rating,
            status: status,
            tie: tie,
            winner_explanation: result[:winner_explanation],
          )

        { status: status, detail: detail }
      end

      def expected_comparison_cell(candidate_label:, winner:, tie:, failure:, status_line:, output:)
        status =
          if tie
            :pass
          elsif winner.present?
            candidate_label == winner ? :pass : :fail
          else
            :unknown
          end

        detail =
          expected_comparison_detail(
            status: status,
            tie: tie,
            failure: failure,
            status_line: status_line,
            candidate_label: candidate_label,
            winner: winner,
            output: output,
          )

        { status: status, detail: detail }
      end

      def comparison_detail(rating:, status:, tie:, winner_explanation:)
        return rating_summary(rating) || "Tie" if tie
        return nil if status == :unknown

        rating_text = rating_summary(rating)
        return rating_text if rating_text.present? && status == :fail

        parts = []
        parts << "Winner" if status == :pass
        parts << rating_text if rating_text.present?
        parts << "Reason: #{winner_explanation}" if status == :pass && winner_explanation.present?

        parts.join(" • ") if parts.any?
      end

      def judged_summary_cell(result)
        winner_label = normalize_label(result[:winner]).presence || result[:winner_label]
        tie = tie_result?(result[:winner], result[:winner_label])

        status = tie ? :tie : :pass
        detail =
          if tie
            winner_reason = result[:winner_explanation]
            winner_reason.present? ? "Tie — #{winner_reason}" : "Result: tie"
          elsif winner_label.present?
            parts = []
            parts << "Winner: #{winner_label}"
            if result[:winner_explanation].present?
              parts << "Reason: #{result[:winner_explanation]}"
            end
            parts.join(" | ")
          else
            "Result: no winner"
          end

        { status: status, detail: detail }
      end

      def expected_comparison_detail(
        status:,
        tie:,
        failure:,
        status_line:,
        candidate_label:,
        winner:,
        output:
      )
        return nil if status == :unknown
        return format_failure(failure) if failure.present?
        return truncate(output, SAMPLE_WIDTH) if status == :pass && output.present?
        return truncate(status_line.to_s, SAMPLE_WIDTH) if status == :pass && status_line.present?
        return "Tie" if tie && status == :pass

        if winner.present?
          suffix = status == :pass ? "Winner" : "Lost"
          return "#{candidate_label} (#{suffix})"
        end

        nil
      end

      def rating_detail(rating)
        return if rating.blank?

        explanation = rating[:explanation].presence
        if explanation
          "Rating: #{rating[:rating]}/10 — #{explanation}"
        else
          "Rating: #{rating[:rating]}/10"
        end
      end

      def rating_summary(rating)
        return if rating.blank?

        explanation = rating[:explanation].presence
        explanation ? "#{rating[:rating]}/10 — #{explanation}" : "#{rating[:rating]}/10"
      end

      def format_failure(failure)
        parts = []
        parts << "Expected: #{stringify(failure[:expected])}" if failure[:expected].present?
        parts << "Actual: #{stringify(failure[:actual])}" if failure[:actual].present?
        truncate(parts.join(" | "), SAMPLE_WIDTH)
      end

      def detail_for_skip(result)
        result[:message] || "Skipped"
      end

      def label_for(metadata, index, row_prefix, label_suffix: nil)
        base =
          if metadata.blank?
            row_prefix.presence || "Case #{index + 1}"
          else
            candidates = %i[input message query content prompt text]
            found = candidates.map { |key| metadata[key] }.compact.find { |value| value.present? }
            if found.present?
              truncate(found.to_s.gsub(/\s+/, " "), SAMPLE_WIDTH)
            else
              row_prefix.presence || "Case #{index + 1}"
            end
          end

        label = row_prefix.present? && base != row_prefix ? "[#{row_prefix}] #{base}" : base
        label_suffix.present? ? "#{label} (#{label_suffix})" : label
      end

      def bump_progress(units, llm_label)
        return if @total_targets <= 0

        @completed_units += units
        render_progress(llm_label)
      end

      def render_progress(llm_label)
        return unless progress_active?
        percent = @total_units.zero? ? 1.0 : @completed_units.to_f / @total_units
        percent = percent.clamp(0.0, 1.0)
        filled = (percent * PROGRESS_BAR_WIDTH).round
        bar = "#{"█" * filled}#{"░" * (PROGRESS_BAR_WIDTH - filled)}"
        label = truncate(llm_label, 18)
        message =
          format(
            "\rEvaluating [%s] %3d%% | %d/%d | %s",
            bar,
            (percent * 100).round,
            @completed_units,
            @total_units,
            label,
          )
        output.print(message)
        output.flush
      end

      def clear_progress_line
        output.print("\r\033[K")
      end

      def progress_active?
        @total_units.present?
      end

      def build_table
        column_widths = compute_column_widths
        lines = []
        lines << top_border(column_widths)
        lines << header_row(column_widths)
        lines << header_separator(column_widths)

        rows.each_with_index do |row, index|
          lines.concat(row_lines(row, column_widths))
          lines << middle_separator(column_widths) unless index == rows.length - 1
        end

        lines << bottom_border(column_widths)
        lines.join("\n")
      end

      def compute_column_widths
        widths = []
        widths << [case_header.length, *rows.map { |row| row[:label].to_s.length }].max

        columns.each do |column|
          column_content_widths =
            rows.map { |row| cell_lines(row[:cells][column]) }.flatten.map(&:length)
          widths << [column.length, *column_content_widths].max
        end

        clamp_widths(widths)
      end

      def case_header
        "input"
      end

      def header_row(widths)
        cells = []
        cells << padded(case_header, widths.first)
        columns.each_with_index { |col, index| cells << padded(col, widths[index + 1]) }
        "│ #{cells.join(" │ ")} │"
      end

      def top_border(widths)
        pieces = widths.map { |w| "─" * (w + 2) }
        "┌#{pieces.join("┬")}┐"
      end

      def header_separator(widths)
        pieces = widths.map { |w| "─" * (w + 2) }
        "├#{pieces.join("┼")}┤"
      end

      def middle_separator(widths)
        pieces = widths.map { |w| "─" * (w + 2) }
        "├#{pieces.join("┼")}┤"
      end

      def bottom_border(widths)
        pieces = widths.map { |w| "─" * (w + 2) }
        "└#{pieces.join("┴")}┘"
      end

      def row_lines(row, widths)
        cell_line_sets = []
        cell_line_sets << wrap_cell(row[:label].to_s, widths.first)

        columns.each_with_index do |column, index|
          cell_line_sets << wrap_cell_lines(row[:cells][column], widths[index + 1])
        end

        max_lines = cell_line_sets.map(&:length).max
        padded_sets = cell_line_sets.map { |lines| pad_lines(lines, max_lines) }

        padded_sets.transpose.map do |line_group|
          "│ #{line_group.map.with_index { |content, idx| padded(content, widths[idx]) }.join(" │ ")} │"
        end
      end

      def wrap_cell(content, width)
        wrap_text(content, width)
      end

      def wrap_cell_lines(cell, width)
        return wrap_text("—", width) if cell.nil?

        status_line =
          case cell[:status]
          when :pass
            "[PASS]"
          when :fail
            "[FAIL]"
          when :skipped
            "[SKIP]"
          when :tie
            "[TIE]"
          else
            "[N/A]"
          end

        detail_lines =
          if cell[:detail].present?
            wrap_text(cell[:detail], width)
          else
            []
          end

        [status_line] + detail_lines
      end

      def pad_lines(lines, target_size)
        lines + Array.new([target_size - lines.length, 0].max, "")
      end

      def wrap_text(text, width)
        sanitized = text.to_s.gsub(/\s+/, " ").strip
        return [""] if sanitized.empty?

        segments = []
        current = +""

        sanitized
          .split(" ")
          .each do |word|
            if current.empty?
              current << word
            elsif (current.length + 1 + word.length) <= width
              current << " " << word
            else
              segments << current
              current = word.dup
            end
          end

        segments << current unless current.empty?
        segments
      end

      def padded(content, width)
        content.to_s.ljust(width)
      end

      def cell_lines(cell)
        wrap_cell_lines(cell, SAMPLE_WIDTH)
      end

      def truncate(value, max_length)
        stringified = stringify(value)
        return stringified if stringified.length <= max_length

        "#{stringified[0...max_length - 1]}…"
      end

      def normalize_label(label)
        label.to_s
      end

      def stringify(value)
        value.is_a?(Regexp) ? value.inspect : value.to_s
      end

      def extract_raw(raw_entry)
        return if raw_entry.nil?

        if raw_entry.is_a?(Hash)
          raw_entry[:raw] || raw_entry[:output] || raw_entry[:result]
        else
          raw_entry
        end
      end

      def refresh_total_units
        @total_units = rows.length * @total_targets
      end

      def register_comparison_columns(candidates)
        candidates.each { |candidate| register_column(candidate[:display_label]) }
      end

      def summary_line
        return "" if columns.empty? || rows.empty?

        totals =
          columns.map do |column|
            stats = column_stats(column)
            "#{column}: #{stats[:pass]}/#{stats[:total]} pass"
          end

        "Summary: #{totals.join(" | ")}"
      end

      def legend_line
        "Legend: [PASS]=pass, [FAIL]=fail, [SKIP]=skipped, [TIE]=tie"
      end

      def column_stats(column)
        counts = Hash.new(0)
        rows.each do |row|
          cell = row[:cells][column]
          status = cell&.dig(:status) || :unknown
          counts[status] += 1
        end

        {
          pass: counts[:pass] + counts[:tie],
          fail: counts[:fail],
          skipped: counts[:skipped],
          total: rows.length,
        }
      end

      def clamp_widths(widths)
        return widths if @max_table_width.nil?

        clamped = widths.map { |w| [w, SAMPLE_WIDTH].min }
        while table_width(clamped) > @max_table_width && clamped.any? { |w| w > MIN_CELL_WIDTH }
          index = clamped.each_with_index.max_by { |width, _idx| width }[1]
          clamped[index] = [clamped[index] - 1, MIN_CELL_WIDTH].max
        end
        clamped
      end

      def table_width(widths)
        return 0 if widths.empty?

        widths.sum + (3 * (widths.length - 1)) + 4
      end

      def detect_max_width
        env_width =
          begin
            Integer(ENV["COLUMNS"])
          rescue StandardError
            nil
          end

        width = env_width || DEFAULT_MAX_WIDTH
        width >= 40 ? width : nil
      end

      def tie_result?(winner, winner_label)
        winner.to_s == "tie" || winner_label.to_s.casecmp("tie").zero?
      end

      def label_suffix_for_winner(winner, winner_label)
        return "tie" if tie_result?(winner, winner_label)
        return nil if winner.blank? && winner_label.blank?

        winner.presence || winner_label
      end
    end
  end
end
