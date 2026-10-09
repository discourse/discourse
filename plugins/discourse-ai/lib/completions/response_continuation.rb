# frozen_string_literal: true

module DiscourseAi
  module Completions
    class ResponseContinuation
      INSTRUCTION = <<~TEXT.strip
        The previous response reached its output allowance. No further tool calls are available.
        Start by copying the exact text in the JSON string below, then continue that text naturally.
        Do not quote or format the copied text. Finish briefly using the information already gathered.
      TEXT

      def self.hint?(content)
        content.is_a?(String) && content.start_with?("#{INSTRUCTION}\n")
      end

      def initialize(previous_text)
        @prefix = previous_text[-120..] || previous_text
        @prefix = @prefix.sub(/\A\S*\s+/, "") if @prefix.length < previous_text.length
        @prefix = @prefix.strip
        @strip_whitespace = previous_text.match?(/\s\z/)
        @pending = +""
        @text = +""
        @started = false
      end

      attr_reader :text

      def hint
        "#{INSTRUCTION}\n#{JSON.generate(@prefix)}"
      end

      def <<(part)
        if !@started
          @pending << part
          candidate = @pending.lstrip
          return "" if candidate.length < @prefix.length && @prefix.start_with?(candidate)
          part = candidate.start_with?(@prefix) ? candidate.delete_prefix(@prefix) : @pending
          @pending = +""
          @started = true
        end
        if @strip_whitespace
          part = part.lstrip
          @strip_whitespace = part.empty?
        end
        @text << part
        part
      end
    end
  end
end
