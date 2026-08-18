# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # Byte-level predicates for a single Markdown line, holding no state of
        # their own. {BlockTracker} uses them both for its per-line block pass and
        # for the lookaheads that bound an inline span.
        #
        # Positions in and out are BYTE offsets and every byte is read with
        # `getbyte`, so no line is ever materialized — this runs at every line of
        # every post. Indentation, in contrast, is counted in COLUMNS: that is what
        # CommonMark's four-space thresholds mean once a tab is involved.
        module LineClassifier
          # A tab advances to the next multiple of four.
          TAB_STOP = 4

          # Bytes a line may start with and still not be plain paragraph text:
          # whitespace (which carries indentation) and the first byte of every
          # construct {BlockTracker} models. Anything else settles the line as
          # paragraph text without looking further, which is the case that has to
          # stay cheap.
          SPECIAL_LINE_START =
            begin
              table = Array.new(256, false)
              "\t\n\r #*+-0123456789<=>[_`~".each_byte { |byte| table[byte] = true }
              table.freeze
            end

          # The bbcode tags core registers as BLOCK rules, so a line opening one of
          # them interrupts a paragraph. Plugins register more, which is why the
          # block pass sticks to this verified set: an unknown `[foo]` line leaves
          # the paragraph open, and a following indented line then reads as prose.
          BLOCK_BBCODE_TAGS = %w[code quote excerpt].freeze
          private_constant :BLOCK_BBCODE_TAGS

          class << self
            # Whether everything from +pos+ to the line end is whitespace. A `\r`
            # counts, so a CRLF body's blank lines, fence closers and bbcode
            # openers read the same as an LF body's.
            def whitespace_only?(input, pos, line_end)
              while pos < line_end
                byte = input.getbyte(pos)
                return false unless byte == 0x20 || byte == 0x09 || byte == 0x0d # space, tab, CR
                pos += 1
              end
              true
            end

            def run_length(input, pos, limit, byte)
              scan = pos
              scan += 1 while scan < limit && input.getbyte(scan) == byte
              scan - pos
            end

            # The fence length when the line opens a fenced code block, else 0.
            # CommonMark forbids a backtick in a backtick fence's info string, and
            # that rule is enforced: reading such a line as a fence would swallow
            # everything after it as code, which is the direction that loses
            # embeds.
            def fence_open_length(input, pos, line_end)
              byte = input.getbyte(pos)
              return 0 unless byte == 0x60 || byte == 0x7e # 0x60 = `, 0x7e = ~

              length = run_length(input, pos, line_end, byte)
              return 0 if length < 3

              if byte == 0x60
                scan = pos + length
                while scan < line_end
                  return 0 if input.getbyte(scan) == 0x60
                  scan += 1
                end
              end

              length
            end

            # A fence closes on a run of its own character, at least as long as the
            # opener's, with nothing but whitespace after it.
            def fence_close?(input, pos, line_end, fence_byte, fence_length)
              return false unless input.getbyte(pos) == fence_byte

              length = run_length(input, pos, line_end, fence_byte)
              length >= fence_length && whitespace_only?(input, pos + length, line_end)
            end

            def atx_heading?(input, pos, line_end)
              level = run_length(input, pos, line_end, 0x23) # 0x23 = #
              return false if level.zero? || level > 6

              byte = input.getbyte(pos + level)
              pos + level >= line_end || byte == 0x20 || byte == 0x09 || byte == 0x0d
            end

            # A thematic break: at least three of one of `-`, `*` or `_`, with
            # nothing but whitespace between and after them.
            def thematic_break?(input, pos, line_end)
              byte = input.getbyte(pos)
              return false unless byte == 0x2d || byte == 0x2a || byte == 0x5f # - * _

              count = 0
              scan = pos
              while scan < line_end
                current = input.getbyte(scan)
                if current == byte
                  count += 1
                elsif current != 0x20 && current != 0x09 && current != 0x0d
                  return false
                end
                scan += 1
              end

              count >= 3
            end

            # A setext underline: one unbroken run of `-` or `=` with nothing but
            # whitespace after it. Such a line only IS an underline below an open
            # paragraph, which is the caller's question to settle.
            def setext_underline?(input, pos, line_end)
              byte = input.getbyte(pos)
              return false unless byte == 0x2d || byte == 0x3d # - =

              run_end = pos + run_length(input, pos, line_end, byte)
              whitespace_only?(input, run_end, line_end)
            end

            # The byte just past a list marker at +pos+ (`-`, `*`, `+`, `1.`, `1)`),
            # or nil. The marker needs whitespace after it, or to be the whole line.
            def list_marker_end(input, pos, line_end)
              byte = input.getbyte(pos)

              if byte == 0x2d || byte == 0x2a || byte == 0x2b # - * +
                marker_end = pos + 1
              else
                digits = 0
                while (digit = input.getbyte(pos + digits)) && digit >= 0x30 && digit <= 0x39
                  digits += 1
                end
                return nil if digits.zero? || digits > 9

                delimiter = input.getbyte(pos + digits)
                return nil unless delimiter == 0x2e || delimiter == 0x29 # . )
                marker_end = pos + digits + 1
              end

              return marker_end if marker_end >= line_end

              after = input.getbyte(marker_end)
              marker_end if after == 0x20 || after == 0x09 || after == 0x0d
            end

            # markdown-it only lets a list interrupt a paragraph when its first line
            # has content and, for an ordered list, when it starts at 1.
            def list_interrupts?(input, pos, marker_end, line_end)
              return false if whitespace_only?(input, marker_end, line_end)

              byte = input.getbyte(pos)
              return true if byte == 0x2d || byte == 0x2a || byte == 0x2b # - * +

              marker_end == pos + 2 && byte == 0x31 # 0x31 = 1
            end

            # Whether the line opens one of the bbcode tags core registers as a
            # block rule.
            def block_bbcode_opener?(input, pos, line_end)
              BLOCK_BBCODE_TAGS.any? { |tag| bbcode_open_end(input, pos, line_end, tag) }
            end

            # Whether the line looks like ANY bbcode opening tag. Used only to bound
            # an inline span, where over-reporting is safe: the span then does not
            # form, its opener stays literal, and what follows stays detectable.
            def bbcode_opener?(input, pos, line_end)
              return false unless input.getbyte(pos) == 0x5b # 0x5b = [

              byte = input.getbyte(pos + 1)
              return false if byte.nil? || !tag_name_byte?(byte)

              scan = pos + 2
              while scan < line_end
                byte = input.getbyte(scan)
                return true if byte == 0x5d # 0x5d = ]
                return false if byte == 0x0a
                scan += 1
              end
              false
            end

            # The byte just past a `[code]` opener — `[code]`, `[code=ruby]`,
            # `[code lang=ruby]` — or nil. Case-insensitive, like core's tag parser.
            def code_tag_open_end(input, pos, line_end)
              bbcode_open_end(input, pos, line_end, "code")
            end

            # The byte just past a `[/code]` closer at +pos+, or nil.
            def code_tag_close_end(input, pos, line_end)
              return nil unless input.getbyte(pos) == 0x5b # 0x5b = [
              return nil unless pos + 7 <= line_end && matches?(input, pos + 1, "/code]")

              pos + 7
            end

            # A `<pre` HTML block opener: CommonMark ends the tag name at
            # whitespace, `>` or the line end. Anything else — `<pretty>` — is a
            # different HTML block, which is not modelled and so reads as prose.
            def pre_tag_open?(input, pos, line_end)
              return false unless input.getbyte(pos) == 0x3c # 0x3c = <
              return false unless matches?(input, pos + 1, "pre")

              byte = input.getbyte(pos + 4)
              pos + 4 >= line_end || byte == 0x3e || byte == 0x20 || byte == 0x09 || byte == 0x0d
            end

            # A table's delimiter row (`-|-`, `:--|--:`), which turns the line above
            # it into a header and so ends the paragraph one line early.
            def delimiter_row?(input, pos, line_end)
              dashes = 0
              scan = pos
              while scan < line_end
                byte = input.getbyte(scan)
                if byte == 0x2d # 0x2d = -
                  dashes += 1
                elsif byte != 0x7c && byte != 0x3a && byte != 0x20 && byte != 0x09 && byte != 0x0d
                  return false # 0x7c = |, 0x3a = :
                end
                scan += 1
              end
              dashes > 0
            end

            def contains_pipe?(input, pos, line_end)
              index = input.byteindex("|", pos)
              !index.nil? && index < line_end
            end

            private

            # The byte just past `[<tag>]` or `[<tag>=…]` / `[<tag> …]` at +pos+, or
            # nil. Attributes run to the first `]` on the line; the quoted-attribute
            # exotica core also accepts falls through to prose, which is safe.
            def bbcode_open_end(input, pos, line_end, tag)
              return nil unless input.getbyte(pos) == 0x5b # 0x5b = [
              return nil unless matches?(input, pos + 1, tag)

              scan = pos + 1 + tag.bytesize
              byte = input.getbyte(scan)
              return scan + 1 if byte == 0x5d # 0x5d = ]
              return nil unless byte == 0x3d || byte == 0x20 || byte == 0x09 # = space tab

              while scan < line_end
                return scan + 1 if input.getbyte(scan) == 0x5d
                scan += 1
              end
              nil
            end

            # Case-insensitive ASCII comparison against a lowercase literal, so a
            # tag never has to be sliced out of the input.
            def matches?(input, pos, text)
              index = 0
              size = text.bytesize
              while index < size
                byte = input.getbyte(pos + index)
                return false if byte.nil?
                byte |= 0x20 if byte >= 0x41 && byte <= 0x5a # fold A-Z to a-z
                return false unless byte == text.getbyte(index)
                index += 1
              end
              true
            end

            def tag_name_byte?(byte)
              (byte >= 0x61 && byte <= 0x7a) || (byte >= 0x41 && byte <= 0x5a) # a-z A-Z
            end
          end
        end
      end
    end
  end
end
