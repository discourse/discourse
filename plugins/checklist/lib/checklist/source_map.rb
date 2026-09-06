# frozen_string_literal: true

module Checklist
  class SourceMap
    LINE_ENDING_PATTERN = /\r\n|\r|\n/
    MARKER_PATTERN = /\[[ xX]?\]/
    TOGGLEABLE_SEGMENTS = [Checkbox::UNCHECKED, Checkbox::CHECKED, "[]"].freeze

    def initialize(raw)
      @raw = raw
    end

    def checkbox_at(line:, nth:)
      line_start = line_starts[line]
      return if line_start.nil?

      line_end = line_starts[line + 1] || @raw.length
      line_content = @raw[line_start...line_end]
      # Count marker-shaped text consumed by Markdown too; the tokenizer uses the same physical ordinal.
      match = line_content.to_enum(:scan, MARKER_PATTERN).map { Regexp.last_match }[nth]
      return if match.nil? || TOGGLEABLE_SEGMENTS.exclude?(match[0])

      Checkbox.new(offset: line_start + match.begin(0), segment: match[0])
    end

    private

    def line_starts
      @line_starts ||=
        begin
          starts = [0]
          @raw.scan(LINE_ENDING_PATTERN) { starts << Regexp.last_match.end(0) }
          starts
        end
    end
  end
end
