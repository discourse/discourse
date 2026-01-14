# frozen_string_literal: true

module DiscourseAi
  module Completions
    # will work for anthropic and open ai compatible
    class JsonStreamDecoder
      attr_reader :buffer

      LINE_REGEX = /data: ({.*})\s*$/

      def initialize(symbolize_keys: true, line_regex: LINE_REGEX)
        @symbolize_keys = symbolize_keys
        @buffer = +""
        @line_regex = line_regex
      end

      def <<(raw)
        @buffer << raw.to_s
        rval = []

        split = @buffer.scan(/.*\n?/)
        split.pop if split.last.blank?

        @buffer = +(split.pop.to_s)

        split.each do |line|
          matches = line.match(@line_regex)
          next if !matches
          rval << JSON.parse(matches[1], symbolize_names: @symbolize_keys)
        end

        if @buffer.present?
          matches = @buffer.match(@line_regex)
          if matches
            begin
              rval << JSON.parse(matches[1], symbolize_names: @symbolize_keys)
              @buffer = +""
            rescue JSON::ParserError
              # maybe it is a partial line
            end
          end
        end

        rval
      end
    end
  end
end
