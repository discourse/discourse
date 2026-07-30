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
        # newline) is ASCII, so it works in bytes throughout and never materializes a
        # line — this runs at every line start of every post.
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
            indented = code_indent?(input, pos, input_length)

            # Outside a block only the indent can open one, and the first byte settles
            # that for nearly every line — so the ordinary line is neither sliced nor
            # searched for its end.
            unless @in_indented_block
              return nil unless indented && opens_indented_block?(input, pos, input_length)

              @in_indented_block = true
              return pos_after_line(line_end_at(input, pos, input_length), input_length)
            end

            line_end = line_end_at(input, pos, input_length)
            # A blank line doesn't end an indented block — CommonMark lets blank
            # lines separate chunks of one block — so only a non-blank line without
            # the code indent closes it.
            if indented || blank_line?(input, pos, line_end)
              pos_after_line(line_end, input_length)
            else
              @in_indented_block = false
              nil
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

          # CommonMark's blank line: empty, or spaces and tabs only. Ends a paragraph
          # and separates the chunks of one indented block.
          def blank_line?(input, line_start, line_end)
            pos = line_start
            while pos < line_end
              byte = input.getbyte(pos)
              return false unless byte == 0x20 || byte == 0x09 # space or tab
              pos += 1
            end
            true
          end

          # CommonMark opens (and continues) indented code at four leading spaces or
          # a tab; a smaller indent is an ordinary line. Four spaces can't straddle a
          # line end, so reading them as bytes needs no line boundary.
          def code_indent?(input, pos, input_length)
            byte = input.getbyte(pos)
            return true if byte == 0x09 # tab
            return false unless byte == 0x20 # space

            pos + 3 < input_length && input.getbyte(pos + 1) == 0x20 &&
              input.getbyte(pos + 2) == 0x20 && input.getbyte(pos + 3) == 0x20
          end

          def line_end_at(input, pos, input_length)
            input.byteindex("\n", pos) || input_length
          end

          # Whether an indent at +pos+ really opens a code block. Only the shapes
          # that can be read from the line before are treated as code:
          #
          #  * the line before must be blank (or absent) — CommonMark does not let
          #    indented code interrupt a paragraph; and
          #  * the last line with content on it must be neither a list item nor
          #    itself indented, because inside a list the threshold is the item's
          #    content indent plus four (`- ` needs six spaces, `1. ` seven), which
          #    can't be known without tracking list nesting.
          #
          # Anything less clear is left as ordinary content. The two mistakes are not
          # equal: reading real code as content only rewrites text inside a code
          # sample, while reading content as code drops the upload, so the file is
          # never carried over and its URL resolves to nothing.
          #
          # Only reached on a line that already starts with four spaces or a tab, so
          # the walk backwards is rare.
          def opens_indented_block?(input, pos, input_length)
            line_start = previous_line_start(input, pos)
            return true if line_start.nil? # start of input

            line_end = line_end_at(input, line_start, input_length)
            return false unless blank_line?(input, line_start, line_end)

            loop do
              line_start = previous_line_start(input, line_start)
              return true if line_start.nil?

              line_end = line_end_at(input, line_start, input_length)
              next if blank_line?(input, line_start, line_end)

              byte = input.getbyte(line_start)
              return false if byte == 0x20 || byte == 0x09 # indented: list content
              return !list_item_line?(input, line_start, line_end)
            end
          end

          # The start of the line before +pos+, or nil when +pos+ is on the first
          # line. +pos+ is always a line start, so the byte before it is that line's
          # newline.
          def previous_line_start(input, pos)
            return nil if pos.zero?
            # The previous line is the first one; searching from a negative offset
            # would wrap around to the end of the input.
            return 0 if pos < 2

            newline = input.byterindex("\n", pos - 2)
            newline ? newline + 1 : 0
          end

          # A bullet (`-`, `*`, `+`) or ordered (`1.`, `1)`) list marker, under the
          # four-space indent that would make the line code itself.
          def list_item_line?(input, line_start, line_end)
            pos = skip_leading_spaces(input, line_start)
            byte = input.getbyte(pos)
            return false if byte.nil?

            if byte == 0x2d || byte == 0x2a || byte == 0x2b # - * +
              pos += 1
            else
              digits = 0
              digits += 1 while (b = input.getbyte(pos + digits)) && b >= 0x30 && b <= 0x39
              return false if digits.zero? || digits > 9

              pos += digits
              delimiter = input.getbyte(pos)
              return false unless delimiter == 0x2e || delimiter == 0x29 # . )
              pos += 1
            end

            # The marker needs whitespace after it, or to be the whole line.
            pos >= line_end || input.getbyte(pos) == 0x20 || input.getbyte(pos) == 0x09
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
