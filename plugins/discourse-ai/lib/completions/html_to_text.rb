# frozen_string_literal: true

module DiscourseAi
  module Completions
    class HtmlToText
      include TextNormalization

      MAX_INPUT_BYTES = 1 * 1024 * 1024

      def self.convert(path)
        new(path).convert
      end

      def initialize(path)
        @path = path
      end

      def convert
        normalize_document_text(::HtmlToMarkdown.new(read_input).to_markdown)
      end

      private

      attr_reader :path

      def read_input
        input = File.binread(path, MAX_INPUT_BYTES + 1) || +""
        input = input.byteslice(0, MAX_INPUT_BYTES) if input.bytesize > MAX_INPUT_BYTES

        Encodings.force_utf8(input.force_encoding(Encoding::UTF_8))
      end
    end
  end
end
