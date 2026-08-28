# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Constructs
          # Parses the opening tag of a Discourse quote (`[quote=…]`); the body
          # and `[/quote]` stay in place, and any embeds inside the body are
          # still extracted. The {EngineScanner} calls this only where a parsed
          # quote block token shows that core actually renders the tag, so
          # no block-position or forward checks live here.
          #
          # The header is read the way core's bbcode-block.js does: it can be
          # unquoted (`[quote=bob, post:1]`) or wrapped in any of the quotation-mark
          # pairs core recognizes (straight, curly, guillemets, …); a matching pair
          # is stripped, a mismatched or one-sided mark stays a literal character.
          #
          # A header whose first slot is not a name — `[quote="post:5, topic:9"]` —
          # yields no node. That slot is the username to core, whatever it
          # holds: it cooks `data-username="post:5"` and no `data-post` at all, so
          # there are no coordinates there to remap. Rewriting it would mean giving
          # the header a reading core does not have.
          class Quote < Base
            # Case-insensitive because core's bbcode rules are: `[QUOTE=bob]` renders
            # the same block, and missing it leaves the header's source numbering in
            # the imported raw.
            #
            # The header class excludes the newline (core parses the tag within its
            # line) and is capped: a real header holds a username of at most 60
            # characters plus short coordinates, so nothing meaningful comes close
            # to the cap — while an uncapped class would let a body full of
            # unclosed `[quote=` openers re-scan its whole tail per opener,
            # quadratically.
            OPENING = /\G\[quote=(?<header>[^\]\n]{0,512})\]/i
            private_constant :OPENING

            # Whether the `[quote=` opener at `pos` parses as a header shape at
            # all. Separates "parsed, but carries nothing remappable" (skipped
            # like core rendering it without coordinates) from "the grammar
            # could not take it" — the engine tier reports the latter, since an
            # unparseable header may still hold remappable fields.
            def parseable_opener?(input, pos)
              match_at(OPENING, input, pos) ? true : false
            end

            def detect_block_opener(input, pos)
              match = match_at(OPENING, input, pos)
              return nil unless match

              username, name, post_number, topic_id =
                parse_header(strip_quote_marks(match[:header]))
              return nil if username.nil?

              Match.new(
                start_pos: pos,
                end_pos: match.byteoffset(0).last,
                node: QuoteReference.new(username:, name:, post_number:, topic_id:),
              )
            end

            private

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
            # With an explicit `username:` part, that is the username and the bare
            # tokens before the first recognized part are the display name, joined
            # back with a comma: a name containing one splits into several parts,
            # which core (quotes.js) reassembles the same way. Kept only when it
            # differs from the username. Without a `username:` part, the leading
            # token IS the username and any comma tail is dropped, as core does:
            # Discourse omits `username:` exactly when the display name equals the
            # username, so a lone token is not a distinct name.
            def parse_header(string)
              explicit_username = nil
              post_number = topic_id = nil
              name_parts = []
              leading = true

              string
                .split(",")
                .map(&:strip)
                .each do |part|
                  case part
                  when POST_PART
                    post_number = Regexp.last_match(1).to_i
                    leading = false
                  when TOPIC_PART
                    topic_id = Regexp.last_match(1).to_i
                    leading = false
                  when USERNAME_PART
                    explicit_username = Regexp.last_match(1)
                    leading = false
                  else
                    name_parts << part if leading && part.present?
                  end
                end

              if explicit_username
                name = name_parts.join(", ").presence
                display_name = name if name && name != explicit_username
                [explicit_username, display_name, post_number, topic_id]
              else
                [name_parts.first, nil, post_number, topic_id]
              end
            end
          end
        end
      end
    end
  end
end
