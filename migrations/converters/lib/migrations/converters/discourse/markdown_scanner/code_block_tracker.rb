# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # Tracks whether the current position is inside a code block: fenced
        # (``` ``` ``` / `~~~`), indented (4+ spaces or a tab), or inline (`` ` ``).
        #
        # Positions in and out are BYTE offsets, to match the {Scanner}'s byte-offset
        # walk. Every structural character it inspects (backtick, tilde, space, tab,
        # newline) is ASCII, so it works in bytes throughout; the one place it touches
        # arbitrary content, the indented-code line, is byteslice'd into a proper
        # UTF-8 string before the whitespace/indent checks run on it.
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
          def check_fenced_boundary(input, pos)
            input_length = input.bytesize
            scan_pos = skip_leading_spaces(input, pos)
            fence_byte = input.getbyte(scan_pos)
            return nil unless fence_byte == 0x60 || fence_byte == 0x7e # 0x60 = `, 0x7e = ~

            fence_length, scan_pos = count_fence_chars(input, scan_pos, fence_byte, input_length)
            return nil if fence_length < 3

            if @in_fenced_block
              try_close_fence(input, scan_pos, fence_byte, fence_length, input_length)
            else
              open_fence(input, scan_pos, fence_byte, fence_length, input_length)
            end
          end

          # @return [Integer, nil] end position after an indented-code line, or nil.
          def check_indented_boundary(input, pos)
            return nil if @in_fenced_block

            input_length = input.bytesize
            line_end = input.byteindex("\n", pos) || input_length
            line_content = input.byteslice(pos...line_end)
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
            return nil if input.getbyte(pos) != 0x60 # 0x60 = backtick

            input_length = input.bytesize
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
            while spaces < 3 && input.getbyte(scan_pos) == 0x20 # 0x20 = space
              spaces += 1
              scan_pos += 1
            end
            scan_pos
          end

          def count_fence_chars(input, scan_pos, fence_byte, input_length)
            fence_length = 0
            while scan_pos < input_length && input.getbyte(scan_pos) == fence_byte
              fence_length += 1
              scan_pos += 1
            end
            [fence_length, scan_pos]
          end

          def try_close_fence(input, scan_pos, fence_byte, fence_length, input_length)
            return nil unless fence_byte == @fence_byte && fence_length >= @fence_length

            scan_pos += 1 while scan_pos < input_length && input.getbyte(scan_pos) == 0x20 # space
            return nil unless scan_pos >= input_length || input.getbyte(scan_pos) == 0x0a # newline

            @in_fenced_block = false
            pos_after_line(scan_pos, input_length)
          end

          def open_fence(input, scan_pos, fence_byte, fence_length, input_length)
            scan_pos += 1 while scan_pos < input_length && input.getbyte(scan_pos) != 0x0a # newline

            @in_fenced_block = true
            @fence_byte = fence_byte
            @fence_length = fence_length
            pos_after_line(scan_pos, input_length)
          end

          # A backtick run closes an inline span only when its length matches the
          # opening delimiter's exactly (CommonMark). Count the whole run at `pos`
          # and consume all of it either way: on a match, close and return the
          # position after it; on a mismatch (a shorter or a longer run), the run is
          # literal code, so stay inside the span but still return past it — that
          # keeps the next close attempt landing on a run start instead of stepping
          # one backtick into this run, where a length-2 run's second backtick could
          # otherwise be mistaken for a length-1 close.
          def try_close_inline(input, pos, input_length)
            run_end = pos
            run_end += 1 while run_end < input_length && input.getbyte(run_end) == 0x60 # 0x60 = backtick

            @in_inline_code = false if run_end - pos == @inline_delimiter.bytesize
            run_end
          end

          def open_inline(input, pos, input_length)
            delimiter_start = pos
            pos += 1 while pos < input_length && input.getbyte(pos) == 0x60 # backtick

            @inline_delimiter = input.byteslice(delimiter_start...pos)
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
