# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # Tracks code context for the {Scanner}. Two block-level states are stateful
        # because they span many lines: fenced (``` ``` ``` / `~~~`) and indented (4+
        # spaces or a tab). Inline code (`` `…` ``) is not a state — a backtick run is
        # resolved to its whole span (or to a literal run) in one lookahead at the
        # opener, so nothing carries across positions.
        #
        # Positions in and out are BYTE offsets, to match the {Scanner}'s byte-offset
        # walk. Every structural character it inspects (backtick, tilde, space, tab,
        # newline) is ASCII, so it works in bytes throughout; the one place it touches
        # arbitrary content, the indented-code line, is byteslice'd into a proper
        # UTF-8 string before the whitespace/indent checks run on it.
        class CodeBlockTracker
          def initialize
            @in_fenced_block = false
            @in_indented_block = false
          end

          def in_code?
            @in_fenced_block || @in_indented_block
          end

          # @return [Integer, nil] end position after a fence, or nil.
          def check_fenced_boundary(input, pos)
            input_length = input.bytesize
            scan_pos = skip_leading_spaces(input, pos)
            fence_byte = input.getbyte(scan_pos)
            return nil unless fence_byte == 0x60 || fence_byte == 0x7e # 0x60 = `, 0x7e = ~

            fence_length, scan_pos = count_fence_chars(input, scan_pos, fence_byte, input_length)
            # A fence is at least three backticks or tildes (CommonMark); a shorter
            # run is an inline-code delimiter or plain text, not a fence.
            return nil if fence_length < 3

            if @in_fenced_block
              try_close_fence(input, scan_pos, fence_byte, fence_length, input_length)
            else
              open_fence(input, scan_pos, fence_byte, fence_length, input_length)
            end
          end

          # @return [Integer, nil] end position after an indented-code line, or nil.
          def check_indented_boundary(input, pos)
            # Inside a fenced block every line is literal fence content, so an indent
            # there must not open a separate indented block.
            return nil if @in_fenced_block

            input_length = input.bytesize
            line_end = input.byteindex("\n", pos) || input_length
            line_content = input.byteslice(pos...line_end)
            is_blank = line_content.match?(/\A\s*\z/)
            # CommonMark opens (and continues) indented code at four leading spaces or
            # a tab; a smaller indent is an ordinary line.
            has_code_indent = line_content.start_with?("    ") || line_content.start_with?("\t")

            if @in_indented_block
              # A blank line doesn't end an indented block — CommonMark lets blank
              # lines separate chunks of one block — so only a non-blank line without
              # the code indent closes it.
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

          # Resolves the backtick run at +pos+ (which is not inside a block code
          # context) and returns the byte offset just past it: past the whole code
          # span when the run opens one, or past the run itself when it stays literal.
          # The caller appends that slice verbatim and resumes there either way — a
          # literal backtick run holds no embeds, and a span's content is code.
          #
          # CommonMark code-span rules, verified against PrettyText:
          #  - the maximal run at +pos+ is the opener; a span closes on a run of the
          #    SAME length that is itself a full backtick string (not touching more
          #    backticks), so a lone backtick inside a `` `` `` span is content, and a
          #    run of the wrong length never closes;
          #  - inline parsing is per-paragraph, so the closer must appear before the
          #    paragraph ends. A blank line (empty or spaces/tabs only) ends it, and so
          #    does a line that opens a fenced code block: block structure is decided
          #    before inline spans, so such a fence interrupts the paragraph and the
          #    opener stays literal. A single newline inside the span is fine — its two
          #    lines are still one paragraph.
          #
          # A run without a closer scans forward to its paragraph's end once; the walk
          # then resumes just past the run, so each backtick run is examined once.
          def inline_span_end(input, pos)
            input_length = input.bytesize
            run_length = count_backticks(input, pos, input_length)
            run_end = pos + run_length

            bound = paragraph_bound(input, run_end, input_length)
            closer_start = closing_run_position(input, run_end, run_length, bound)
            closer_start ? closer_start + run_length : run_end
          end

          private

          # A fence may carry up to three leading spaces and still be a fence
          # (CommonMark); a fourth space would make the line indented code instead, so
          # the skip stops at three.
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

          # CommonMark closes a fence only with the opener's own fence character, a
          # run at least as long as the opener's, and nothing but spaces between it
          # and the line end — a shorter run, a different character, or trailing text
          # keeps the line as literal content of the block.
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

          def count_backticks(input, pos, input_length)
            run_end = pos
            run_end += 1 while run_end < input_length && input.getbyte(run_end) == 0x60 # backtick
            run_end - pos
          end

          # The byte offset where the opener's paragraph ends: the start of the first
          # following blank or fenced-code-opener line, or the input's end. The
          # opener's own line always belongs to the paragraph, so the scan begins at
          # the next line.
          def paragraph_bound(input, from, input_length)
            line_end = input.byteindex("\n", from) || input_length

            loop do
              return input_length if line_end >= input_length

              line_start = line_end + 1
              return input_length if line_start >= input_length

              next_line_end = input.byteindex("\n", line_start) || input_length
              if blank_line?(input, line_start, next_line_end) ||
                   fence_opener_line?(input, line_start)
                return line_start
              end

              line_end = next_line_end
            end
          end

          def blank_line?(input, line_start, line_end)
            pos = line_start
            while pos < line_end
              byte = input.getbyte(pos)
              return false unless byte == 0x20 || byte == 0x09 # space or tab
              pos += 1
            end
            true
          end

          # Matches the opener rule of {#check_fenced_boundary}: up to three leading
          # spaces then a run of at least three backticks or tildes.
          def fence_opener_line?(input, line_start)
            pos = skip_leading_spaces(input, line_start)
            fence_byte = input.getbyte(pos)
            return false unless fence_byte == 0x60 || fence_byte == 0x7e # 0x60 = `, 0x7e = ~

            run = 0
            run += 1 while input.getbyte(pos + run) == fence_byte
            run >= 3
          end

          # Finds the start of the closing backtick run — a run of exactly +run_length+
          # backticks — searching within [from, bound). A run of any other length is
          # not a closer; its backticks are stepped over whole, since backticks inside
          # a maximal run can't start a separate closer.
          def closing_run_position(input, from, run_length, bound)
            pos = from
            while pos < bound
              if input.getbyte(pos) == 0x60 # backtick
                run_start = pos
                pos += 1 while pos < bound && input.getbyte(pos) == 0x60
                return run_start if pos - run_start == run_length
              else
                pos += 1
              end
            end
            nil
          end

          # Advance to the next line's start by stepping over the trailing newline; at
          # end of input there's no newline to step over, so the position is returned
          # unchanged.
          def pos_after_line(line_end, input_length)
            line_end < input_length ? line_end + 1 : line_end
          end
        end
      end
    end
  end
end
