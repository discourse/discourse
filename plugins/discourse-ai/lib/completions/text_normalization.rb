# frozen_string_literal: true

module DiscourseAi
  module Completions
    module TextNormalization
      DOCUMENT_TEXT_BUDGET = 100_000

      # one past the budget, so DocumentEncoder#truncate_extracted_text can tell a document
      # was cut short and say so in the prompt
      MAX_EXTRACTED_TEXT_CHARS = DOCUMENT_TEXT_BUDGET + 1

      def force_utf8(text)
        ::Encodings.force_utf8(text.to_s)
      end

      def normalize_document_text(text)
        force_utf8(text)
          .first(MAX_EXTRACTED_TEXT_CHARS)
          .gsub("\u00A0", " ")
          .gsub(/\r\n?/, "\n")
          .gsub(/[ \t]+\n/, "\n")
          .gsub(/\n{3,}/, "\n\n")
          .strip
      end

      def normalize_inline_text(text)
        force_utf8(text).gsub("\u00A0", " ").gsub(/\s+/, " ").strip
      end
    end
  end
end
