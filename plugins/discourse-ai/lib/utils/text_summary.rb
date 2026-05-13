# frozen_string_literal: true

module DiscourseAi
  module Utils
    # Small helpers for trimming and summarizing free-form text before
    # we hand it to an LLM. Centralized so we don't reinvent the
    # truncation rule in every caller.
    class TextSummary
      DEFAULT_MAX_CHARS = 1_000


      # Returns the text truncated to `max` characters with an ellipsis
      # appended, or the original text if it already fits.
      #
      # Returns nil for nil input so callers can chain `&.`.
      def self.truncate(text, max: DEFAULT_MAX_CHARS)
        return nil if text.nil?
        return text if text.length <= max
        "#{text[0, max]} …"
      end


      def self.word_count(text)
        return 0 if text.nil? || text.empty?
        text.split(/\s+/).reject(&:empty?).length
      end
    end
  end
end
