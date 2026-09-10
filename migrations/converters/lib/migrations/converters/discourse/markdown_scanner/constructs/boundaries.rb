# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Constructs
          # The boundary look-arounds the URL constructs share: whether core
          # lets a link open at a position, given what sits next to it. Each
          # takes the input and a byte offset, tests the neighboring byte as
          # ASCII first, and falls back to the recovered character for a
          # Unicode-aware test.
          #
          # The name-gated constructs have no boundary rules at all — see
          # {MarkdownScanner}. And wherever only ASCII bytes are tested (`(`,
          # `]`, `)`, `!`), a multibyte previous character's trailing byte can
          # never equal them, so those checks need no character recovery.
          module Boundaries
            private

            # markdown-it linkifies a bare absolute schemed URL (`https://…`) in
            # prose unless the character right before its scheme is an ASCII
            # letter, digit, `+` or `\`. Two of core's engines feed this and
            # their admissions are unioned: the inline rule
            # (`markdown-it/rules_inline/linkify.mjs`, whose `SCHEME_RE` accepts
            # a scheme after anything outside `[A-Za-z0-9.+-]`) and the core
            # ruler (`rules_core/linkify.mjs` via linkify-it, which also admits
            # `.` and `-` as Unicode punctuation). That leaves only
            # `[A-Za-z0-9+]` non-admitting, plus `\`, which markdown escapes
            # into the following character so no link forms. Verified against
            # PrettyText.
            #
            # A byte >= 0x80 is a multibyte tail, therefore outside
            # `[A-Za-z0-9+\]` and always a boundary.
            def linkify_boundary_before?(input, pos)
              return true if pos.zero?

              byte = input.getbyte(pos - 1)
              byte >= 0x80 || !linkify_non_boundary_ascii_byte?(byte)
            end

            # The ASCII characters that do NOT open a bare linkified URL:
            # letters, digits, `+`, and `\` (a markdown escape).
            def linkify_non_boundary_ascii_byte?(byte)
              (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5a) ||
                (byte >= 0x61 && byte <= 0x7a) || byte == 0x2b || byte == 0x5c # `+` `\`
            end

            # The character set markdown-it's core-ruler linkify (linkify-it)
            # admits right before a bare protocol-relative `//host` URL: a
            # Unicode separator, punctuation or control character, or one of the
            # three separators it lists explicitly (`<`, `>`, `｜`). Narrower
            # than the schemed-URL boundary above, because the inline rule that
            # widens that one only fires on `scheme://` — so a symbol like `²`
            # or `€` before a `//host` does not open a link. Verified against
            # PrettyText.
            CORE_RULER_BOUNDARY = /[\p{Z}\p{P}\p{Cc}<>｜]/
            private_constant :CORE_RULER_BOUNDARY

            # Whether a bare protocol-relative `//host` URL may open at `pos`.
            # linkify-it's `//` schema rejects a `//` right after `:` or `/`
            # (the `://` tail of a scheme we already declined, or a `///` typo)
            # and excludes `_` like every linkify boundary; otherwise it admits
            # its {CORE_RULER_BOUNDARY} set.
            def protocol_relative_boundary_before?(input, pos)
              return true if pos.zero?

              byte = input.getbyte(pos - 1)
              return false if byte == 0x3a || byte == 0x2f || byte == 0x5f # `:` `/` `_`

              char = byte < 0x80 ? byte.chr : previous_char(input, pos)
              CORE_RULER_BOUNDARY.match?(char)
            end

            # A bare match beginning `//host` is protocol-relative and uses the
            # narrower {#protocol_relative_boundary_before?} set. The `/`
            # trigger fires on every `/`, including the `//` inside a
            # `https://…` the `h` trigger already declined, so this rejects that
            # scheme tail too.
            def inadmissible_protocol_relative?(input, pos, url)
              url.start_with?("//") && !protocol_relative_boundary_before?(input, pos)
            end

            # The `](…)` outer-link-target boundary: the URL sits right after a
            # `](` and a `)` closes right before the `]`. That only happens when
            # the bracket wrapped a construct that was already consumed — the
            # outer link of a nested image `[![img](upload)](/t/5)` or an old
            # lightbox — so the URL here is a genuine link target, which is
            # where `Base#detect_bare_url` admits a relative one.
            def link_target_boundary_before?(input, pos)
              # 0x29 = `)`
              pos >= 3 && link_destination_before?(input, pos) && input.getbyte(pos - 3) == 0x29
            end

            # A `](` right before `pos`: the destination of a link or image,
            # whose parens delimit the URL. {#link_target_boundary_before?}
            # names the narrower nested-construct shape.
            def link_destination_before?(input, pos)
              # 0x28 = `(`, 0x5d = `]`
              pos >= 2 && input.getbyte(pos - 1) == 0x28 && input.getbyte(pos - 2) == 0x5d
            end

            def bang_before?(input, pos)
              return false if pos.zero?

              input.getbyte(pos - 1) == 0x21 # `!`
            end

            # The character ending just before `pos`, for the Unicode-aware
            # look-backs. `pos` sits on a character boundary, so a multibyte
            # previous character is the continuation bytes (`10xxxxxx`) right
            # before `pos` plus their lead byte.
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
