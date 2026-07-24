# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Detectors
          # Detects only the opening tag of a Discourse quote (`[quote=…]`); the
          # body and `[/quote]` stay in place, and any embeds inside the body are
          # still scanned. Returns nil for a `[quote]` with no header.
          #
          # The header is read the way core's bbcode-block.js does: it can be
          # unquoted (`[quote=bob, post:1]`) or wrapped in any of the quotation-mark
          # pairs core recognizes (straight, curly, guillemets, …); a matching pair
          # is stripped, a mismatched or one-sided mark stays a literal character.
          #
          # Core only renders the block when nothing but spaces or tabs follow the
          # opening tag to the end of its line, so we make the same forward check.
          # We deliberately skip core's block-position rules (line start, a real
          # `[/quote]` further down, list context): matching those would need
          # whole-document machinery, and over-extracting a `[quote=…]` that core
          # left as raw BBCode only renumbers text in place at import — the header
          # is rebuilt where it stands. The one thing the forward check gives up is
          # core's single-line inline form `[quote=bob]body[/quote]`, whose body is
          # not spaces-only; that stays literal here. Verified against PrettyText.
          class Quote < Base
            TRIGGERS = ["["].freeze

            OPENING = /\G\[quote=(?<header>[^\]]*)\]/
            private_constant :OPENING

            def detect(input, pos, _byte)
              match = match_at(OPENING, input, pos)
              return nil unless match

              end_pos = match.byteoffset(0).last
              return nil unless trailing_space_only?(input, end_pos)

              username, name, post_number, topic_id =
                parse_header(strip_quote_marks(match[:header]))
              return nil if username.nil?

              Match.new(
                start_pos: pos,
                end_pos:,
                node: QuoteReference.new(username:, name:, post_number:, topic_id:),
              )
            end

            private

            # Core renders the quote block only when the opening tag is followed by
            # nothing but spaces or tabs to the end of its line. `pos` is the byte
            # right after the tag; scan forward until the first line terminator (or
            # the end of input) and reject anything that isn't a space or tab. A `\r`
            # ends the line like `\n` because markdown-it normalizes CR/CRLF to LF
            # before it parses, so a CRLF after the tag still renders in core.
            # Verified against PrettyText. Byte domain, no allocations.
            def trailing_space_only?(input, pos)
              size = input.bytesize
              while pos < size
                byte = input.getbyte(pos)
                return true if byte == 0x0a || byte == 0x0d # `\n` `\r`
                return false unless byte == 0x20 || byte == 0x09 # space, tab
                pos += 1
              end
              true
            end

            # The quotation-mark pairs core strips from a quote header, mirroring
            # `QUOTATION_MARKS` in discourse-markdown-it's bbcode-block.js. Each is an
            # `[opening, closing]` pair. Core strips a pair only when the header opens
            # with the opening mark and closes with THAT pair's closing mark around at
            # least one character; a mismatched or one-sided mark (`[quote="bob']`,
            # `[quote="bob]`) and an empty pair (`[quote=""]`) are left literal, so
            # the marks become part of the header. Verified against PrettyText.
            QUOTE_MARK_PAIRS = [
              %w[" "],
              %w[' '],
              %w[« »],
              %w[“ ”],
              %w[” ”],
              %w[‘ ’],
              %w[„ “],
              %w[‚ ’],
              %w[‹ ›],
            ].freeze
            private_constant :QUOTE_MARK_PAIRS

            def strip_quote_marks(header)
              QUOTE_MARK_PAIRS.each do |opening, closing|
                if header.length > opening.length + closing.length && header.start_with?(opening) &&
                     header.end_with?(closing)
                  return header[opening.length...(header.length - closing.length)]
                end
              end
              header
            end

            # The id bound (see `Base::ID_PATTERN`): an overlong run names no real
            # record, so the part is ignored like any unrecognized one.
            POST_PART = /\Apost:(#{Base::ID_PATTERN})\z/
            private_constant :POST_PART

            TOPIC_PART = /\Atopic:(#{Base::ID_PATTERN})\z/
            private_constant :TOPIC_PART

            USERNAME_PART = /\Ausername:(.+)\z/
            private_constant :USERNAME_PART

            # Splits a quote header into username, display name, and the source
            # coordinates. `post:`/`topic:` are the source's own post number
            # and topic id; keep them as integers so the importer can look up the
            # quoted post by them.
            #
            # With an explicit `username:` part, that is the username and the leading
            # bare token is the display name (kept only when it differs). Without one,
            # the leading token IS the username: Discourse omits `username:` exactly
            # when the display name equals the username, so a lone token is not a
            # distinct name.
            def parse_header(string)
              explicit_username = name = nil
              post_number = topic_id = nil

              string
                .split(",")
                .map(&:strip)
                .each_with_index do |part, index|
                  case part
                  when POST_PART
                    post_number = Regexp.last_match(1).to_i
                  when TOPIC_PART
                    topic_id = Regexp.last_match(1).to_i
                  when USERNAME_PART
                    explicit_username = Regexp.last_match(1)
                  else
                    name = part if index.zero? && part.present?
                  end
                end

              if explicit_username
                display_name = name if name && name != explicit_username
                [explicit_username, display_name, post_number, topic_id]
              else
                [name, nil, post_number, topic_id]
              end
            end
          end
        end
      end
    end
  end
end
