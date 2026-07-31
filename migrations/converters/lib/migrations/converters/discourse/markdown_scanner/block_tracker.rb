# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # Decides, line by line, whether the {Scanner} is looking at code. It runs a
        # cut-down CommonMark BLOCK phase — the containers (blockquote, list item)
        # and the leaf blocks that can be code (fenced, indented) — plus Discourse's
        # own code forms: a `[code]` block, an inline `[code]…[/code]` span and a
        # `<pre>` HTML block. Everything else about a line only matters through the
        # one bit the block phase leaves behind: whether a paragraph is open, which
        # is what decides whether an indented line is code or a lazy continuation.
        #
        # One instance per {Scanner#scan}. Positions in and out are BYTE offsets,
        # and every offset returned comes from a `byteindex` or an ASCII scan, so it
        # always lands on a character boundary.
        #
        # Where core's behaviour cannot be reproduced cheaply, the ambiguity is
        # resolved toward NOT code. Reading real code as content only rewrites text
        # inside a code sample; reading content as code drops the embed, so the
        # upload is never carried over and its URL resolves to nothing.
        class BlockTracker
          # Lookahead patterns for the two forms whose end is a plain substring.
          # Case-insensitive, like core's tag matching.
          CODE_CLOSE_PATTERN = %r{\[/code\]}i
          PRE_CLOSE_PATTERN = %r{</pre>}i
          CODE_CLOSE_LENGTH = "[/code]".bytesize
          private_constant :CODE_CLOSE_PATTERN, :PRE_CLOSE_PATTERN, :CODE_CLOSE_LENGTH

          # Stands in for the container stack until a post actually opens one, so
          # the common post costs no array at all.
          NO_CONTAINERS = [].freeze
          private_constant :NO_CONTAINERS

          def initialize
            # Open containers, outermost first, packed as `content_column << 1 | bit`
            # (bit 1 = list item, 0 = blockquote) so that opening one allocates
            # nothing even on a deeply nested post.
            @containers = NO_CONTAINERS
            @paragraph_open = false
            @code_leaf = nil # nil, :fence or :indented
            @code_depth = 0
            @fence_byte = 0
            @fence_length = 0
            # The paragraph whose bound was computed last, as [lo, hi). Successive
            # spans in one paragraph share it, which keeps the lookaheads linear.
            @bound_lo = 0
            @bound_hi = 0
            @no_code_close_from = nil
            @no_pre_close_from = nil
            @code_close_hit = nil
            @code_close_scanned_from = nil
            @code_close_memo = nil
          end

          # Called at every line start. Returns the byte offset just past the
          # consumed region when the line is (or begins) code — a fence line, a
          # fenced or indented interior line, or a whole `[code]` or `<pre>` block in
          # one go — and nil when the line is prose for the {Scanner} to walk.
          def process_line(input, pos)
            # At top level with no code block open, a line starting with an ordinary
            # character can only be paragraph text. That is nearly every line of
            # nearly every post, and it must not cost more than one byte read.
            if @containers.empty? && @code_leaf.nil? &&
                 !LineClassifier::SPECIAL_LINE_START[input.getbyte(pos)]
              @paragraph_open = true
              return nil
            end

            length = input.bytesize
            line_end = input.byteindex("\n", pos) || length

            matched = match_containers(input, pos, line_end)
            content_pos = skip_whitespace(input, @scan_pos, @scan_col, line_end)
            indent = @ws_col - @base_col

            if LineClassifier.whitespace_only?(input, content_pos, line_end)
              @paragraph_open = false
              close_containers(matched)
              # A blank line separates the chunks of one indented block rather than
              # closing it, and inside a fence it is ordinary content.
              return @code_leaf ? pos_after_line(line_end, length) : nil
            end

            # A paragraph swallows every line no block rule interrupts it with,
            # including an indented one — which is why indented code cannot open in
            # the middle of a paragraph, and why an unmatched container prefix is
            # still a lazy continuation.
            lazy =
              @paragraph_open && lazy_continuation?(input, content_pos, line_end, indent, matched)

            if matched < @containers.size
              return nil if lazy

              close_containers(matched)
              @paragraph_open = false
            end

            if @code_leaf == :fence
              if indent < 4 &&
                   LineClassifier.fence_close?(
                     input,
                     content_pos,
                     line_end,
                     @fence_byte,
                     @fence_length,
                   )
                @code_leaf = nil
              end
              return pos_after_line(line_end, length)
            end

            if @code_leaf == :indented
              return pos_after_line(line_end, length) if indent >= 4
              @code_leaf = nil
            end

            return nil if lazy

            open_blocks(input, pos, content_pos, indent, line_end, length)
          end

          # Resolves the backtick run at +pos+ and returns the byte offset just past
          # it: past the whole code span when the run opens one, past the run itself
          # when it stays literal. The caller appends that slice verbatim and resumes
          # there either way — a literal backtick run holds no embeds, and a span's
          # content is code.
          #
          # CommonMark code-span rules, verified against PrettyText: the maximal run
          # at +pos+ is the opener, and a span closes on a run of the SAME length
          # that is itself a full backtick string — so a lone backtick inside a
          # `` `` `` span is content, and a run of the wrong length never closes.
          # Inline parsing is per paragraph, so the closer must fall before the
          # paragraph ends.
          def backtick_span_end(input, pos)
            run_length = LineClassifier.run_length(input, pos, input.bytesize, 0x60) # 0x60 = `
            run_end = pos + run_length

            bound = paragraph_bound(input, run_end)
            closer_start = closing_run_position(input, run_end, run_length, bound)
            closer_start ? closer_start + run_length : run_end
          end

          # Resolves an inline `[code]…[/code]` span at +pos+ and returns the byte
          # offset just past its closer, or nil when the `[` opens no span. Core
          # matches the closer greedily and case-insensitively within the paragraph,
          # and runs the link rule first — so the {Scanner} only asks once every
          # detector has declined.
          def code_tag_span_end(input, pos)
            length = input.bytesize
            line_end = input.byteindex("\n", pos) || length
            open_end = LineClassifier.code_tag_open_end(input, pos, line_end)
            return nil unless open_end

            close_start = find_code_close(input, open_end, paragraph_bound(input, open_end))
            close_start && close_start + CODE_CLOSE_LENGTH
          end

          private

          # Advances past the prefixes of the open containers this line still
          # matches, leaving @scan_pos/@scan_col just past the last matched one and
          # @base_col at the column its content starts in.
          #
          # @return [Integer] how many containers matched.
          def match_containers(input, pos, line_end)
            @scan_pos = pos
            @scan_col = 0
            @base_col = 0
            matched = 0

            while matched < @containers.size
              entry = @containers[matched]
              content_pos = skip_whitespace(input, @scan_pos, @scan_col, line_end)
              blank = LineClassifier.whitespace_only?(input, content_pos, line_end)

              if entry & 1 == 1 # list item
                content_col = entry >> 1
                # A blank line does not end a list item; it separates its blocks.
                break if !blank && @ws_col < content_col

                @base_col = content_col
                unless blank
                  @scan_pos = content_pos
                  @scan_col = @ws_col
                end
              else
                # A blank line ends a blockquote, and so does a line without its
                # marker — unless the line lazily continues a paragraph, which the
                # caller settles.
                break if blank || @ws_col - @base_col > 3
                break if input.getbyte(content_pos) != 0x3e # 0x3e = >

                col = @ws_col + 1
                scan = content_pos + 1
                byte = input.getbyte(scan)
                if byte == 0x20 # space
                  scan += 1
                  col += 1
                elsif byte == 0x09 # tab
                  scan += 1
                  col += LineClassifier::TAB_STOP - (col % LineClassifier::TAB_STOP)
                end
                @scan_pos = scan
                @scan_col = col
                @base_col = col
              end

              matched += 1
            end

            matched
          end

          def push_container(entry)
            @containers = [] if @containers.frozen?
            @containers << entry
          end

          def close_containers(matched)
            @containers.pop while @containers.size > matched
            @code_leaf = nil if @code_leaf && @code_depth > matched
          end

          # The first byte at or after +pos+ that is neither a space nor a tab, with
          # its column left in @ws_col. Columns, not bytes: CommonMark's four-space
          # thresholds count columns, and a tab jumps to the next tab stop.
          def skip_whitespace(input, pos, col, line_end)
            while pos < line_end
              byte = input.getbyte(pos)
              if byte == 0x20 # space
                col += 1
              elsif byte == 0x09 # tab
                col += LineClassifier::TAB_STOP - (col % LineClassifier::TAB_STOP)
              else
                break
              end
              pos += 1
            end
            @ws_col = col
            pos
          end

          # Opens whatever blocks the line starts. Container markers re-base the
          # columns for the rest of the same line, so this loops: `- > ```` opens
          # three blocks in one pass.
          def open_blocks(input, line_start, content_pos, indent, line_end, length)
            loop do
              if indent >= 4
                @paragraph_open = false
                @code_leaf = :indented
                @code_depth = @containers.size
                return pos_after_line(line_end, length)
              end

              byte = input.getbyte(content_pos)

              if byte == 0x3e # 0x3e = > blockquote marker
                @paragraph_open = false
                push_container(0)
                col = @ws_col + 1
                scan = content_pos + 1
                after = input.getbyte(scan)
                if after == 0x20 # space
                  scan += 1
                  col += 1
                elsif after == 0x09 # tab
                  scan += 1
                  col += LineClassifier::TAB_STOP - (col % LineClassifier::TAB_STOP)
                end
                @base_col = col
                content_pos = skip_whitespace(input, scan, col, line_end)
                return nil if LineClassifier.whitespace_only?(input, content_pos, line_end)

                indent = @ws_col - @base_col
                next
              end

              if byte == 0x60 || byte == 0x7e # 0x60 = `, 0x7e = ~
                fence_length = LineClassifier.fence_open_length(input, content_pos, line_end)
                break if fence_length.zero?

                @paragraph_open = false
                @code_leaf = :fence
                @code_depth = @containers.size
                @fence_byte = byte
                @fence_length = fence_length
                return pos_after_line(line_end, length)
              end

              if byte == 0x5b # 0x5b = [
                consumed = code_block_end(input, content_pos, line_end, length)
                break unless consumed

                @paragraph_open = false
                return consumed
              end

              if byte == 0x3c # 0x3c = <
                break unless LineClassifier.pre_tag_open?(input, content_pos, line_end)

                @paragraph_open = false
                return pre_block_end(input, line_start, line_end, length)
              end

              if byte == 0x23 # 0x23 = #
                break unless LineClassifier.atx_heading?(input, content_pos, line_end)

                @paragraph_open = false
                return nil
              end

              # Checked before the list marker, as core's block ruler does, so that
              # `---` is a break rather than an empty bullet. A setext underline
              # only counts under an open paragraph; a lone `-` with none above it
              # falls through to the list marker instead.
              if byte == 0x2d || byte == 0x2a || byte == 0x5f || byte == 0x3d # - * _ =
                if LineClassifier.thematic_break?(input, content_pos, line_end) ||
                     (
                       @paragraph_open &&
                         LineClassifier.setext_underline?(input, content_pos, line_end)
                     )
                  @paragraph_open = false
                  return nil
                end
              end

              if byte == 0x2d || byte == 0x2a || byte == 0x2b || (byte >= 0x30 && byte <= 0x39)
                marker_end = LineClassifier.list_marker_end(input, content_pos, line_end)
                break unless marker_end

                @paragraph_open = false
                content_pos = open_list_item(input, content_pos, marker_end, line_end)
                return nil unless content_pos

                indent = @ws_col - @base_col
                next
              end

              break
            end

            @paragraph_open = true
            nil
          end

          # Pushes the list item and returns where its content starts on this line,
          # or nil when the marker is all there is. markdown-it counts 1–4 spaces
          # after the marker into the item's content column; more than that, or an
          # empty rest, and the content starts one column past the marker.
          def open_list_item(input, content_pos, marker_end, line_end)
            marker_col = @ws_col + (marker_end - content_pos)
            after = skip_whitespace(input, marker_end, marker_col, line_end)
            empty_rest = LineClassifier.whitespace_only?(input, after, line_end)
            spaces = @ws_col - marker_col
            spaces = 1 if spaces > 4 || empty_rest

            content_col = marker_col + spaces
            push_container((content_col << 1) | 1)
            @base_col = content_col
            return nil if empty_rest

            after
          end

          # Whether the open paragraph swallows a line whose container prefix
          # matched +matched+ entries. At the paragraph's own level, any line no
          # block rule interrupts it with continues it. A line that stopped
          # matching the containers continues lazily unless it ends them, which
          # core decides with the containers' terminator rules — where the list
          # restrictions are off and a setext underline is no terminator at all.
          def lazy_continuation?(input, pos, line_end, indent, matched)
            if matched < @containers.size
              !ends_containers?(input, pos, line_end, indent)
            else
              !interrupts_paragraph?(input, pos, line_end, indent)
            end
          end

          # Whether a line starts a block that ends the open paragraph at the
          # paragraph's own level: a setext underline does, and a list only within
          # core's restrictions — an empty item or an ordered item not starting at
          # 1 cannot interrupt. Anything not modelled here leaves the paragraph
          # open, which makes a following indented line read as prose — the
          # direction that cannot lose an embed.
          def interrupts_paragraph?(input, pos, line_end, indent)
            return false if indent >= 4

            byte = input.getbyte(pos)
            return true if LineClassifier.setext_underline?(input, pos, line_end)
            return true if starts_block?(input, pos, line_end, byte)

            if byte == 0x2d || byte == 0x2a || byte == 0x2b || (byte >= 0x30 && byte <= 0x39)
              marker_end = LineClassifier.list_marker_end(input, pos, line_end)
              return(
                !!marker_end && LineClassifier.list_interrupts?(input, pos, marker_end, line_end)
              )
            end

            false
          end

          # Whether a line that stopped matching the open containers terminates
          # them. Core's terminator rules run with the container as the parent, so
          # the paragraph-interruption restrictions on lists do not apply: any
          # list marker line ends the containers, even an empty item.
          def ends_containers?(input, pos, line_end, indent)
            return false if indent >= 4

            byte = input.getbyte(pos)
            return true if starts_block?(input, pos, line_end, byte)

            if byte == 0x2d || byte == 0x2a || byte == 0x2b || (byte >= 0x30 && byte <= 0x39)
              return !!LineClassifier.list_marker_end(input, pos, line_end)
            end

            false
          end

          # The block starts that end a paragraph no matter where it sits: as the
          # terminator arms above differ only on lists and underlines, these are
          # their shared arms. A `-` or `*` line that is not a break falls back to
          # the caller's list handling.
          def starts_block?(input, pos, line_end, byte)
            return true if byte == 0x3e # 0x3e = >

            if byte == 0x60 || byte == 0x7e # 0x60 = `, 0x7e = ~
              return LineClassifier.fence_open_length(input, pos, line_end) > 0
            end
            return LineClassifier.atx_heading?(input, pos, line_end) if byte == 0x23 # 0x23 = #
            return LineClassifier.pre_tag_open?(input, pos, line_end) if byte == 0x3c # 0x3c = <
            if byte == 0x5b # 0x5b = [
              return LineClassifier.block_bbcode_opener?(input, pos, line_end)
            end
            if byte == 0x2d || byte == 0x2a || byte == 0x5f # - * _
              return LineClassifier.thematic_break?(input, pos, line_end)
            end

            false
          end

          # The same question for an inline span's bound, answered liberally: a
          # bounded span does not form, so its opener stays literal and everything
          # after it stays detectable. That lets the two constructs core interrupts
          # on but we cannot recognize — a plugin's bbcode tag and the HTML blocks
          # other than `<pre>` — be treated as interrupting without risk.
          def interrupts_span?(input, pos, line_end, indent)
            return true if indent < 4 && input.getbyte(pos) == 0x3c # 0x3c = <
            return true if indent < 4 && LineClassifier.bbcode_opener?(input, pos, line_end)

            interrupts_paragraph?(input, pos, line_end, indent)
          end

          # The byte offset where the paragraph holding +from+ ends: the start of the
          # first following line that is blank or begins a block. Inline parsing
          # never reaches past it, so a span opened before it cannot close after it.
          def paragraph_bound(input, from)
            return @bound_hi if from >= @bound_lo && from < @bound_hi

            length = input.bytesize
            line_end = input.byteindex("\n", from) || length
            bound = length
            header_start = nil

            loop do
              break if line_end >= length

              line_start = line_end + 1
              break if line_start >= length

              next_end = input.byteindex("\n", line_start) || length
              # A line that no longer matches the containers can still be a lazy
              # continuation, so the containers only re-base the columns here; what
              # ends the paragraph is the line's own shape.
              match_containers(input, line_start, next_end)
              content_pos = skip_whitespace(input, @scan_pos, @scan_col, next_end)
              indent = @ws_col - @base_col

              if LineClassifier.whitespace_only?(input, content_pos, next_end) ||
                   interrupts_span?(input, content_pos, next_end, indent)
                bound = line_start
                break
              end

              if LineClassifier.delimiter_row?(input, content_pos, next_end)
                bound = header_start || line_start
                break
              end

              header_start =
                (line_start if LineClassifier.contains_pipe?(input, content_pos, next_end))
              line_end = next_end
            end

            @bound_lo = from
            @bound_hi = bound
            bound
          end

          # Finds the start of the closing backtick run — a run of exactly
          # +run_length+ backticks — within [from, bound). A run of any other length
          # is not a closer; its backticks are stepped over whole, since backticks
          # inside a maximal run can't start a separate closer.
          def closing_run_position(input, from, run_length, bound)
            pos = from
            while pos < bound
              if input.getbyte(pos) == 0x60 # 0x60 = backtick
                run_start = pos
                pos += 1 while pos < bound && input.getbyte(pos) == 0x60
                return run_start if pos - run_start == run_length
              else
                pos += 1
              end
            end
            nil
          end

          # Resolves a `[code]` BLOCK at the line's content start and returns the
          # byte offset just past it, or nil when the line opens no block. A `[code]`
          # that only the inline rule can close is left to {#code_tag_span_end}, so
          # both forms end up as code without this one having to model either.
          def code_block_end(input, content_pos, line_end, length)
            open_end = LineClassifier.code_tag_open_end(input, content_pos, line_end)
            return nil unless open_end

            # An inline close filling the rest of the line makes that one line a
            # block; a close with anything after it belongs to the inline form.
            close_start = find_code_close(input, open_end, line_end)
            if close_start
              return nil unless close_start + CODE_CLOSE_LENGTH == line_end

              return pos_after_line(line_end, length)
            end

            return nil unless LineClassifier.whitespace_only?(input, open_end, line_end)
            # With no `[/code]` left in the input at all there is no close line to
            # find either, so a post full of unclosed openers stays linear.
            return nil if @no_code_close_from && open_end >= @no_code_close_from

            code_block_close(input, line_end, length)
          end

          # Scans forward for the `[/code]` LINE that closes a block opened on the
          # line ending at +line_end+, tracking nested openers, and returns the
          # byte offset just past it. A line that no longer matches the opener's
          # containers gives up: core's scoping there is murkier than this, and
          # giving up leaves the block as prose.
          #
          # Every nested opener passed over is remembered with its outcome — the
          # close line that paired with it, or the give-up that stranded it. When
          # this block does not form, those openers get processed as lines
          # themselves and would each rescan the same tail; answering them from
          # the memo instead keeps a post full of `[code]` lines linear. The
          # outcome only holds under the container stack it was scanned in, so
          # entries carry it and a lookup must match it.
          def code_block_close(input, line_end, length)
            if (memo = @code_close_memo&.[](line_end)) && memo[0] == @containers
              return memo[1]
            end

            depth = @containers.size
            containers = @containers.frozen? ? @containers : @containers.dup
            openers = [line_end]
            scan_end = line_end

            loop do
              line_start = scan_end + 1
              return memoize_code_closes(containers, openers, nil) if line_start >= length

              scan_end = input.byteindex("\n", line_start) || length
              if match_containers(input, line_start, scan_end) < depth
                return memoize_code_closes(containers, openers, nil)
              end

              content_pos = skip_whitespace(input, @scan_pos, @scan_col, scan_end)
              # Core skips over-indented lines rather than closing on them.
              next if @ws_col - @base_col >= 4
              next unless input.getbyte(content_pos) == 0x5b # 0x5b = [

              close_end = LineClassifier.code_tag_close_end(input, content_pos, scan_end)
              if close_end
                next unless LineClassifier.whitespace_only?(input, close_end, scan_end)

                result = pos_after_line(scan_end, length)
                memoize_code_close(containers, openers.pop, result)
                return result if openers.empty?

                next
              end

              open_end = LineClassifier.code_tag_open_end(input, content_pos, scan_end)
              if open_end && LineClassifier.whitespace_only?(input, open_end, scan_end)
                openers << scan_end
              end
            end
          end

          # A close pairs with the newest pending opener; a scan that gives up
          # strands all of them, and a scan started from a stranded opener would
          # retrace this one's tail to the same end.
          def memoize_code_close(containers, opener_line_end, result)
            (@code_close_memo ||= {})[opener_line_end] = [containers, result]
          end

          def memoize_code_closes(containers, openers, result)
            openers.each do |opener_line_end|
              memoize_code_close(containers, opener_line_end, result)
            end
            result
          end

          # Consumes a `<pre>` HTML block: through the first line holding `</pre>`,
          # or — exactly as core's type-1 HTML block does — to the end of the input
          # when there is none.
          def pre_block_end(input, line_start, line_end, length)
            close_start = find_pre_close(input, line_start)
            depth = @containers.size
            # With no containers to leave, an unclosed block simply runs to the end.
            return length if close_start.nil? && depth.zero?

            loop do
              return pos_after_line(line_end, length) if close_start && close_start < line_end

              next_start = line_end + 1
              return length if next_start >= length

              next_end = input.byteindex("\n", next_start) || length
              # An HTML block is not lazily continued, so it ends where its
              # containers do.
              return next_start if match_containers(input, next_start, next_end) < depth

              line_end = next_end
            end
          end

          # Both lookaheads remember the offset from which their closer is missing
          # for good, so a post full of unclosed openers still scans in one pass.
          # A hit is remembered too: finding it proves the gap between the search
          # start and the hit holds no earlier one, so a later search from inside
          # that gap can answer without rescanning it.
          def find_code_close(input, from, bound)
            return nil if @no_code_close_from && from >= @no_code_close_from

            if @code_close_hit && from >= @code_close_scanned_from && from <= @code_close_hit
              index = @code_close_hit
            else
              index = input.byteindex(CODE_CLOSE_PATTERN, from)
              if index.nil?
                @no_code_close_from = from
                return nil
              end

              @code_close_scanned_from = from
              @code_close_hit = index
            end

            index < bound ? index : nil
          end

          def find_pre_close(input, from)
            return nil if @no_pre_close_from && from >= @no_pre_close_from

            index = input.byteindex(PRE_CLOSE_PATTERN, from)
            @no_pre_close_from = from if index.nil?
            index
          end

          # Advance to the next line's start by stepping over the trailing newline;
          # at the end of input there is no newline to step over.
          def pos_after_line(line_end, length)
            line_end < length ? line_end + 1 : line_end
          end
        end
      end
    end
  end
end
