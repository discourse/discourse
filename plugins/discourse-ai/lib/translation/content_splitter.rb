# frozen_string_literal: true

module DiscourseAi
  module Translation
    class ContentSplitter
      DEFAULT_CHUNK_SIZE = 8192

      BBCODE_PATTERNS = [
        %r{\[table.*?\].*?\[/table\]}m,
        %r{\[quote.*?\].*?\[/quote\]}m,
        %r{\[details.*?\].*?\[/details\]}m,
        %r{\<details.*?\>.*?\</details\>}m,
        %r{\[spoiler.*?\].*?\[/spoiler\]}m,
        %r{\[code.*?\].*?\[/code\]}m,
        /```.*?```/m,
      ].freeze

      TEXT_BOUNDARIES = [
        /\n\s*\n\s*|\r\n\s*\r\n\s*/, # double newlines with optional spaces
        /[.!?]\s+/, # sentence endings
        /[,;]\s+/, # clause endings
        /\n|\r\n/, # single newlines
        /\s+/, # any whitespace
      ].freeze

      def self.split(content:, chunk_size: DEFAULT_CHUNK_SIZE, &measure)
        return [] if content.nil?
        return [""] if content.empty?
        chunk_size ||= DEFAULT_CHUNK_SIZE
        raise ArgumentError, "Chunk size must be positive" if chunk_size <= 0

        chunks = []
        offset = 0

        while offset < content.length
          chunk = content[offset..]
          loop do
            length = fitting_length(chunk, chunk_size, &measure)
            break if length == chunk.length

            chunk = extract_mixed_chunk(chunk, size: length)
            break if !measure || measure.call(chunk) <= chunk_size
          end

          chunks << chunk
          offset += chunk.length
        end

        chunks
      end

      private

      def self.fitting_length(text, size, &measure)
        return [text.length, size].min if !measure
        return text.length if measure.call(text) <= size

        lower = 0
        upper = text.length
        while lower + 1 < upper
          middle = (lower + upper) / 2
          if measure.call(text[0...middle]) <= size
            lower = middle
          else
            upper = middle
          end
        end

        raise ArgumentError, "Chunk size is too small to fit content" if lower == 0

        lower
      end

      def self.extract_mixed_chunk(text, size:)
        split_point =
          find_nearest_bbcode_end_index(text, size) || find_nearest_html_end_index(text, size) ||
            find_text_boundary(text, size) || size

        split_point += 1 while split_point < size && text[split_point].match?(/\s/)
        text[0...split_point]
      end

      def self.find_nearest_html_end_index(text, target_pos)
        return if !text.include?("<")

        handler = HtmlBoundaries.new(text, target_pos)
        Nokogiri::HTML4::SAX::Parser
          .new(handler, Encoding::UTF_8)
          .parse_memory(text) { |context| handler.context = context }
        handler.element_end || handler.text_end
      end

      def self.find_nearest_bbcode_end_index(text, target_pos)
        BBCODE_PATTERNS
          .flat_map do |pattern|
            text.to_enum(:scan, pattern).flat_map { Regexp.last_match.offset(0) }
          end
          .select { |position| position.positive? && position <= target_pos }
          .max
      end

      def self.find_text_boundary(text, target_pos)
        TEXT_BOUNDARIES.each do |pattern|
          next if !text[0...target_pos].rindex(pattern)

          return Regexp.last_match.end(0)
        end
        nil
      end

      class HtmlBoundaries < Nokogiri::XML::SAX::Document
        attr_accessor :context
        attr_reader :element_end, :text_end

        def initialize(text, target_pos)
          @target_pos = target_pos
          @line_offsets = [0]
          text.each_line { |line| @line_offsets << @line_offsets.last + line.length }
        end

        def end_element(_name)
          @element_end = source_position || @element_end
        end

        alias_method :comment, :end_element

        def characters(_text)
          @text_end = source_position || @text_end
        end

        alias_method :cdata_block, :characters

        private

        def source_position
          position = @line_offsets[context.line - 1] + context.column - 1
          position if position.positive? && position <= @target_pos
        end
      end
    end
  end
end
