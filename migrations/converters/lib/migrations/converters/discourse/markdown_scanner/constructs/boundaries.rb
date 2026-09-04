# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Constructs
          # The boundary look-arounds the URL constructs share: whether core
          # lets a link open at a position, given what sits next to it. Each
          # takes the input and a byte offset, first tests the neighboring byte
          # as ASCII, and falls back to the recovered character for a
          # Unicode-aware test. Mixed into {Base}, so every construct shares
          # one reading of each boundary.
          #
          # The name-gated constructs (mentions, hashtags, custom emoji) have
          # no boundary rules at all: the engine tier reads what core actually
          # recognized and counts it in the raw, which is why nothing here
          # mirrors their opening conditions any more.
          module Boundaries
            private

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
          end
        end
      end
    end
  end
end
