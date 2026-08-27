# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Constructs
          # The boundary look-arounds shared by the constructs: whether core's
          # engines let a construct open (or close) at a position, given what
          # sits next to it. Each takes the input and a byte offset, first
          # tests the neighboring byte as ASCII, and falls back to the
          # recovered character for a Unicode-aware test. Mixed into {Base},
          # so every construct shares one reading of each boundary.
          module Boundaries
            # The boundary markdown-it's text-post-process engine enforces around a
            # whole match: whitespace or, per markdown-it's `isPunctChar`, a Unicode
            # punctuation or symbol character. `\p{Z}` covers the wide spaces (NBSP,
            # ideographic space) markdown-it counts as whitespace that Ruby's `\s`
            # misses. Shared by the classes whose construct only fires on such a
            # boundary (mentions, hashtags). Verified against PrettyText — this
            # boundary is imposed by the engine, not shown by the rule's own regex.
            PUNCTUATION_OR_SYMBOL = /[\p{P}\p{S}\p{Z}]/
            private_constant :PUNCTUATION_OR_SYMBOL

            # The character set core's emoji rule (`discourse-markdown-it/src/
            # features/emoji.js`) accepts before a shortcode's opening `:`, per
            # markdown-it's `isPunctChar`: a Unicode punctuation or symbol. Unlike
            # {PUNCTUATION_OR_SYMBOL} (the text-post-process boundary shared by
            # mentions and hashtags) this leaves out `\p{Z}`: the emoji rule's
            # `isSpace`/`isPunctChar` both reject the wide spaces (NBSP, ideographic
            # space, category Zs), so a shortcode glued right after one stays
            # literal. Verified against PrettyText.
            EMOJI_PUNCTUATION_OR_SYMBOL = /[\p{P}\p{S}]/
            private_constant :EMOJI_PUNCTUATION_OR_SYMBOL

            # The zero-width space the emoji rule special-cases as a valid character
            # before the opening `:`, alongside whitespace and punctuation. It is
            # category Cf, so neither `isSpace` nor `isPunctChar` covers it.
            ZERO_WIDTH_SPACE = "\u200B"
            private_constant :ZERO_WIDTH_SPACE

            private

            # A mention (`@name`) opens only when the `@` sits on a boundary: the
            # start of input, whitespace, or a punctuation/symbol character. Verified
            # against PrettyText: the engine's boundary is punctuation-or-space, not
            # "not a word character", so a `_` before the `@` (`a_@name`) opens a
            # mention (core cooks it) while `@` glued to a letter or digit does not.
            #
            # `pos` is a byte offset, so `getbyte(pos - 1)` is the last byte of the
            # previous character. An ASCII byte (< 0x80) is that whole character; a
            # byte >= 0x80 is the trailing byte of a multibyte character, so we recover
            # the actual character with {#previous_char} and test it Unicode-aware.
            def mention_boundary_before?(input, pos)
              return true if pos.zero?

              byte = input.getbyte(pos - 1)
              # A `\` escapes the `@` into a literal (`\@name`), so it never opens a
              # mention even though `\` is itself punctuation.
              return false if byte == 0x5c # `\`

              if byte < 0x80
                whitespace_byte?(byte) || ascii_punct_or_symbol_byte?(byte)
              else
                PUNCTUATION_OR_SYMBOL.match?(previous_char(input, pos))
              end
            end

            # The forward half of the same boundary: `pos` is the byte right after the
            # name, and the mention opens only when that is the end of input,
            # whitespace, or a punctuation/symbol character. Verified against
            # PrettyText: `@name²` (a `²`, category No, right after the name) is not a
            # boundary, so core leaves it literal. The name match already stops on a
            # non-word character, so this only rejects the few that are neither a
            # boundary nor a word character (numbers like `²`, format characters).
            def mention_boundary_after?(input, pos)
              return true if pos >= input.bytesize

              byte = input.getbyte(pos)
              if byte < 0x80
                whitespace_byte?(byte) || ascii_punct_or_symbol_byte?(byte)
              else
                PUNCTUATION_OR_SYMBOL.match?(char_at(input, pos))
              end
            end

            # A custom-emoji shortcode opens only when its `:` sits on core's emoji
            # boundary (`emoji.js`'s `isValidEmojiPrecedingChar`): the start of
            # input, a tab or space (markdown-it's narrow `isSpace`) or a newline (a
            # line break splits the text into separate tokens before the emoji rule
            # runs, so a shortcode after one opens at the start of its own fragment),
            # a Unicode punctuation or symbol (`isPunctChar` — which includes the
            # closing `:` of an adjacent shortcode, so `:a::b:` defers both), or the
            # zero-width space the rule special-cases. Verified against PrettyText:
            # NBSP and ideographic space (both Zs), a soft hyphen (Cf), and `²`/`½`
            # (No) are none of these, so core leaves a shortcode after one literal.
            #
            # `pos` is a byte offset, so `getbyte(pos - 1)` is the previous
            # character's last byte: an ASCII byte is that whole character, a byte
            # >= 0x80 its trailing byte, recovered with {#previous_char} and tested
            # Unicode-aware.
            def emoji_boundary_before?(input, pos)
              return true if pos.zero?

              byte = input.getbyte(pos - 1)
              # A `\` escapes the `:` into a literal `:` (core drops the shortcode),
              # so nothing opens after it even though `\` is itself punctuation.
              return false if byte == 0x5c # `\`

              if byte < 0x80
                emoji_space_byte?(byte) || ascii_punct_or_symbol_byte?(byte)
              else
                char = previous_char(input, pos)
                char == ZERO_WIDTH_SPACE || EMOJI_PUNCTUATION_OR_SYMBOL.match?(char)
              end
            end

            # markdown-it's `isSpace` (tab and space) widened by the newline that a
            # line break leaves in front of a shortcode's own text fragment. ASCII-
            # only, so a byte >= 0x80 (part of a multibyte character) is never one of
            # these.
            def emoji_space_byte?(byte)
              byte == 0x20 || byte == 0x09 || byte == 0x0a
            end

            # `/\s/` as a byte test: space plus `\t\n\v\f\r`. ASCII-only, so a byte
            # >= 0x80 (part of a multibyte character) is never whitespace here.
            def whitespace_byte?(byte)
              byte == 0x20 || (byte >= 0x09 && byte <= 0x0d)
            end

            # Where a bare URL may start. This is only the cheap first gate — the URL
            # constructs narrow it further once a match tells them whether the URL is
            # relative or absolute, because the boundary alone doesn't separate the
            # two:
            #
            #   * A `](…)` is a link's or image's target. Admit only the `)](` shape,
            #     where a `)` closes right before the `]` — the bracket wrapped an
            #     already-consumed construct, so the URL is the outer target of a
            #     nested image `[![img](upload)](/t/5)` or an old lightbox, and a
            #     relative or absolute URL there is a real link we rewrite (see
            #     {#link_target_boundary_before?}). A `](…)` after plain bracket text —
            #     `[pic](…)`, `![alt](…)`, `[text](foreign)` — is the image's or
            #     link's own target, handled at its own trigger (an image src is not
            #     ours; a foreign link is signalled once), so firing here would rewrite
            #     an image's source or double-report a foreign host.
            #   * Anywhere else, an absolute (schemed or `//host`) URL is admitted on
            #     core's linkify boundary — every character except an ASCII letter,
            #     digit or `+` (see {#linkify_boundary_before?}). A schemed or `//host`
            #     URL in prose becomes a link once the post is cooked, so rewriting it
            #     keeps a link a link. A relative path like `/t/5` stays plain text
            #     when cooked, so the constructs leave a relative prose URL alone — it
            #     passes this gate but is rejected as relative unless it sits at the
            #     `)](` target above.
            #
            # The bytes tested here (`(`, `]`) are ASCII, so a multibyte previous
            # character can never equal them.
            def bare_url_boundary_before?(input, pos)
              return true if pos.zero?

              # A `(` right after a `]` is a link/image target; only the `)](` shape
              # is admitted, so branch off before the general linkify boundary (a bare
              # `(` is itself a linkify boundary and would otherwise admit any `](`).
              if input.getbyte(pos - 1) == 0x28 && pos >= 2 && input.getbyte(pos - 2) == 0x5d
                # 0x28 = `(`, 0x5d = `]`
                return link_target_boundary_before?(input, pos)
              end

              linkify_boundary_before?(input, pos)
            end

            # markdown-it linkifies a bare absolute schemed URL (`https://…`) in prose
            # unless the character right before its scheme is an ASCII letter, digit,
            # `+` or `\`. Two of core's engines feed this and their admissions are
            # unioned: the inline rule (`markdown-it/rules_inline/linkify.mjs`, whose
            # `SCHEME_RE` accepts a scheme after anything outside `[A-Za-z0-9.+-]`) and
            # the core ruler (`rules_core/linkify.mjs` via linkify-it, which also admits
            # `.` and `-` as Unicode punctuation). What's left non-admitting is only
            # `[A-Za-z0-9+]`, plus `\`, which markdown escapes into the following
            # character so no link forms. Every other character — the rest of ASCII
            # punctuation and symbols, `_`, and any non-ASCII character (a letter, a
            # mark, a space, a symbol) — opens a linkified URL. Verified against
            # PrettyText.
            #
            # `pos` is a byte offset, so `getbyte(pos - 1)` is the previous character's
            # last byte. A byte >= 0x80 is the tail of a multibyte character, which is
            # therefore outside ASCII `[A-Za-z0-9+\]` and always a boundary; only the
            # ASCII letters, digits, `+` and `\` are not.
            def linkify_boundary_before?(input, pos)
              return true if pos.zero?

              byte = input.getbyte(pos - 1)
              byte >= 0x80 || !linkify_non_boundary_ascii_byte?(byte)
            end

            # The ASCII characters that do NOT open a bare linkified URL when they sit
            # right before the scheme: letters, digits, `+`, and `\` (a markdown
            # escape).
            def linkify_non_boundary_ascii_byte?(byte)
              (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5a) ||
                (byte >= 0x61 && byte <= 0x7a) || byte == 0x2b || byte == 0x5c # `+` `\`
            end

            # The character set markdown-it's core-ruler linkify (linkify-it) admits
            # right before a bare protocol-relative `//host` URL: a Unicode separator,
            # punctuation or control character, or one of the three separators it lists
            # explicitly (`<`, `>`, `｜`). This is narrower than the schemed-URL
            # boundary above: the inline rule that widens that one only fires on
            # `scheme://`, so a bare `//host` depends on this core-ruler set alone (a
            # symbol like `²` or `€` before it does not open a link). Verified against
            # PrettyText.
            CORE_RULER_BOUNDARY = /[\p{Z}\p{P}\p{Cc}<>｜]/
            private_constant :CORE_RULER_BOUNDARY

            # Whether a bare protocol-relative `//host` URL may open at `pos`.
            # linkify-it's `//` schema rejects a `//` that sits right after `:` or `/`
            # (the `://` tail of a scheme we already declined, or a `///` typo) and
            # excludes `_` like every linkify boundary; otherwise it admits its
            # {CORE_RULER_BOUNDARY} set. `pos` is a byte offset; an ASCII byte is the
            # whole previous character, a byte >= 0x80 its trailing byte, recovered with
            # {#previous_char}.
            def protocol_relative_boundary_before?(input, pos)
              return true if pos.zero?

              byte = input.getbyte(pos - 1)
              return false if byte == 0x3a || byte == 0x2f || byte == 0x5f # `:` `/` `_`

              char = byte < 0x80 ? byte.chr : previous_char(input, pos)
              CORE_RULER_BOUNDARY.match?(char)
            end

            # A bare match that begins `//host` is protocol-relative and uses the
            # narrower {#protocol_relative_boundary_before?} set. The `/` trigger fires
            # on every `/` in the input, including the `//` inside a `https://…` the
            # `h` trigger already declined, so this rejects that scheme tail (and any
            # other `//` on a boundary core wouldn't linkify a protocol-relative URL
            # at). A schemed or relative match doesn't start `//`, so it's unaffected.
            def inadmissible_protocol_relative?(input, pos, url)
              url.start_with?("//") && !protocol_relative_boundary_before?(input, pos)
            end

            # The `](…)` outer-link-target boundary: the URL sits right after a `](`
            # and a `)` closes right before the `]`, the `)](` shape. That only
            # happens when the bracket wrapped a construct that was already consumed —
            # the outer link of a nested image `[![img](upload)](/t/5)` or an old
            # lightbox — so the URL here is a genuine link target. A relative URL is
            # rewritten only at this boundary, where it is a link and not prose.
            #
            # All the bytes tested are ASCII (`(` 0x28, `]` 0x5d, `)` 0x29), so a
            # multibyte previous character can never equal them.
            def link_target_boundary_before?(input, pos)
              return false if pos < 3

              input.getbyte(pos - 1) == 0x28 && input.getbyte(pos - 2) == 0x5d &&
                input.getbyte(pos - 3) == 0x29
            end

            # `!` is ASCII, so a multibyte previous character's trailing byte simply
            # isn't 0x21.
            def bang_before?(input, pos)
              return false if pos.zero?

              input.getbyte(pos - 1) == 0x21 # `!`
            end

            # Every printable ASCII punctuation or symbol character — the four ranges
            # around the digits and letters (`!`..`/`, `:`..`@`, `[`..`` ` ``,
            # `{`..`~`). These are exactly the ASCII characters markdown-it's
            # `isPunctChar` accepts, so they mirror {PUNCTUATION_OR_SYMBOL} for
            # ASCII input. Space (0x20) is whitespace, tested separately.
            def ascii_punct_or_symbol_byte?(byte)
              (byte >= 0x21 && byte <= 0x2f) || (byte >= 0x3a && byte <= 0x40) ||
                (byte >= 0x5b && byte <= 0x60) || (byte >= 0x7b && byte <= 0x7e)
            end

            # The character ending just before `pos`, for the Unicode-aware
            # look-backs. `pos` sits on a character boundary, so when the previous
            # character is multibyte its bytes are the continuation bytes
            # (`10xxxxxx`) right before `pos` plus their lead byte; walk back over
            # them and byteslice that one character.
            def previous_char(input, pos)
              start = pos - 1
              start -= 1 while (input.getbyte(start) & 0xC0) == 0x80
              input.byteslice(start, pos - start)
            end

            # The character starting at the byte offset `pos`, for the Unicode-aware
            # forward look-aheads. `pos` sits on a character boundary, so walk forward
            # over that character's continuation bytes (`10xxxxxx`) and byteslice the
            # one character. Caller must ensure `pos < input.bytesize`.
            def char_at(input, pos)
              stop = pos + 1
              stop += 1 while stop < input.bytesize && (input.getbyte(stop) & 0xC0) == 0x80
              input.byteslice(pos, stop - pos)
            end
          end
        end
      end
    end
  end
end
