# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # Tracks whether the current position is inside a code block: fenced
        # (``` ``` ``` / `~~~`), indented (4+ spaces or a tab), or inline (`` ` ``).
        class CodeBlockTracker
          attr_reader :in_fenced_block, :in_indented_block, :in_inline_code

          def initialize
            @in_fenced_block = false
            @in_indented_block = false
            @in_inline_code = false
          end

          def in_code?
            @in_fenced_block || @in_indented_block || @in_inline_code
          end

          # @return [Integer, nil] end position after a fence, or nil.
          def check_fenced_boundary(input, pos, line_start:)
            return nil unless line_start

            input_length = input.length
            scan_pos = skip_leading_spaces(input, pos)
            fence_char = input[scan_pos]
            return nil unless fence_char == "`" || fence_char == "~"

            fence_length, scan_pos = count_fence_chars(input, scan_pos, fence_char, input_length)
            return nil if fence_length < 3

            if @in_fenced_block
              try_close_fence(input, scan_pos, fence_char, fence_length, input_length)
            else
              open_fence(input, scan_pos, fence_char, fence_length, input_length)
            end
          end

          # @return [Integer, nil] end position after an indented-code line, or nil.
          def check_indented_boundary(input, pos, line_start:)
            return nil unless line_start
            return nil if @in_fenced_block

            input_length = input.length
            line_end = input.index("\n", pos) || input_length
            line_content = input[pos...line_end]
            is_blank = line_content.match?(/\A\s*\z/)
            has_code_indent = line_content.start_with?("    ") || line_content.start_with?("\t")

            if @in_indented_block
              if is_blank || has_code_indent
                pos_after_line(line_end, input_length)
              else
                @in_indented_block = false
                nil
              end
            elsif has_code_indent
              @in_indented_block = true
              pos_after_line(line_end, input_length)
            end
          end

          # @return [Integer, nil] end position after inline code delimiter, or nil.
          def check_inline_boundary(input, pos)
            return nil if @in_fenced_block || @in_indented_block
            return nil if input[pos] != "`"

            input_length = input.length
            if @in_inline_code
              try_close_inline(input, pos, input_length)
            else
              open_inline(input, pos, input_length)
            end
          end

          private

          def skip_leading_spaces(input, pos)
            scan_pos = pos
            spaces = 0
            while spaces < 3 && input[scan_pos] == " "
              spaces += 1
              scan_pos += 1
            end
            scan_pos
          end

          def count_fence_chars(input, scan_pos, fence_char, input_length)
            fence_length = 0
            while scan_pos < input_length && input[scan_pos] == fence_char
              fence_length += 1
              scan_pos += 1
            end
            [fence_length, scan_pos]
          end

          def try_close_fence(input, scan_pos, fence_char, fence_length, input_length)
            return nil unless fence_char == @fence_char && fence_length >= @fence_length

            scan_pos += 1 while scan_pos < input_length && input[scan_pos] == " "
            return nil unless scan_pos >= input_length || input[scan_pos] == "\n"

            @in_fenced_block = false
            pos_after_line(scan_pos, input_length)
          end

          def open_fence(input, scan_pos, fence_char, fence_length, input_length)
            scan_pos += 1 while scan_pos < input_length && input[scan_pos] != "\n"

            @in_fenced_block = true
            @fence_char = fence_char
            @fence_length = fence_length
            pos_after_line(scan_pos, input_length)
          end

          def try_close_inline(input, pos, input_length)
            delimiter_length = @inline_delimiter.length
            return nil unless input[pos, delimiter_length] == @inline_delimiter

            next_pos = pos + delimiter_length
            return nil if next_pos < input_length && input[next_pos] == "`"

            @in_inline_code = false
            next_pos
          end

          def open_inline(input, pos, input_length)
            delimiter_start = pos
            pos += 1 while pos < input_length && input[pos] == "`"

            @inline_delimiter = input[delimiter_start...pos]
            @in_inline_code = true
            pos
          end

          def pos_after_line(line_end, input_length)
            line_end < input_length ? line_end + 1 : line_end
          end
        end
      end
    end
  end
end
