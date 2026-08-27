# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Constructs
          # Detects uploads referenced by a full URL instead of a short `upload://`
          # one — markdown images `![alt](url)`, markdown links `[text](url)` and
          # bare whitespace-delimited URLs. Two URL shapes are supported, matching
          # what core's file store writes (see core's `Upload` and `FileStore`):
          #
          #   * a long URL: an `/uploads/` or `/secure-uploads/` segment with an
          #     `original/` or `optimized/` path below it, and a basename that
          #     starts with the upload's 40-hex sha1;
          #   * a short-URL path: `/uploads/short-url/<token>[.ext]`, where the
          #     token is the base62-encoded sha1 (core's `Upload#short_path`).
          #     It is decoded here, so the row carries the same 40-hex sha1 as a
          #     long URL and resolves the same way at import.
          #
          # Any other `/uploads/` path (a WordPress `wp-content/uploads/…` URL,
          # some unrelated site's file) is not an upload reference: it matches
          # neither shape and is left alone.
          #
          # Recognition does no host allowlisting: a URL that has a supported
          # shape but points at some other site still resolves to nothing at
          # import and comes back verbatim (see `UploadUrlReference`), so
          # matching it is safe. Both relative and absolute (http/https and
          # protocol-relative) forms are recognized in image and link syntax. A
          # bare URL follows the same rule as an internal link: an absolute bare
          # URL is recognized in prose, a relative one only at a `](…)` link
          # target — a relative path bare in prose stays plain text once cooked,
          # so rewriting it would turn text into a link.
          class UploadUrl < Base
            TRIGGERS = ["!", "[", "h", "H", "/"].freeze

            # The sha1 is 160 bits; base62 needs at most 27 characters for that.
            MAX_SHORT_TOKEN_LENGTH = 27

            # The optional scheme/host and the path segments before the
            # `/uploads/` segment. `[^/#{Base::URL_TERMINATORS}]` is a
            # path-segment character (a URL-body character minus the slash; see
            # `Base::URL_TERMINATORS`). The scheme is case-insensitive because
            # linkify-it reads it that way, so core links `HTTPS://…` too.
            # The repeated group is atomic with a lookahead deciding where it
            # stops, so a failing candidate is scanned once and never
            # backtracked into. The segment-count and length caps bound a
            # single candidate.
            ORIGIN_AND_PREFIX =
              %r{
                (?<origin> (?i:https?:)? // [^/#{Base::URL_TERMINATORS}]{1,255} )?      # optional scheme + host
                (?> (?: / (?! (?:secure-)?uploads/ ) [^/#{Base::URL_TERMINATORS}]{1,255} ){0,16} )
              }x
            private_constant :ORIGIN_AND_PREFIX

            # The long shape, from `/uploads/` down to the sha1 at the start of
            # the basename. The trailing `\w` keeps a sentence's `.`/`,` after a
            # bare URL out of the match. The lookaheads keep lazy semantics
            # without lazy quantifiers: the first `original|optimized/` and the
            # first sha1-shaped basename win.
            LONG_TAIL =
              %r{
                / (?:secure-)? uploads /
                (?> (?: (?! (?:original|optimized)/ ) [^/#{Base::URL_TERMINATORS}]{1,255} / ){0,16} )
                (?: original | optimized ) /
                (?> (?: (?! \h{40}[._] ) [^/#{Base::URL_TERMINATORS}]{1,255} / ){0,16} )  # depth/partition segments
                (?<sha1> \h{40} ) (?=[._])                                              # sha1, then the extension or `_WxH` suffix
                [^#{Base::URL_TERMINATORS}]{0,255} \w
              }x
            private_constant :LONG_TAIL

            # The short-URL shape. The token is base62, the extension optional
            # (core routes both spellings). `(?![\w/-])` stops the match when
            # more path follows — core's short-URL route has exactly one
            # segment after `short-url/`.
            SHORT_TAIL =
              %r{/uploads/short-url/(?<short_token>[0-9a-zA-Z]{1,#{MAX_SHORT_TOKEN_LENGTH}})(?:\.\w{1,15})?(?![\w/-])}x
            private_constant :SHORT_TAIL

            URL = /(?<upload_url>#{ORIGIN_AND_PREFIX}(?:#{LONG_TAIL}|#{SHORT_TAIL}))/
            private_constant :URL

            # `\G` anchors each match at `pos` so scanning stays linear. The alt
            # class excludes `[` for the same reason as `LINK` below: a nested image
            # `![![…](…)](…)` must not match from the outer `!`.
            # The label caps are CommonMark's own 999-character link-label limit.
            IMAGE = /\G!\[[^\[\]]{0,999}\]\(#{Base::LINK_GAP}#{URL}#{Base::LINK_TAIL}/
            private_constant :IMAGE

            # The text class excludes `[` so the `[` of a nested image
            # `[![…](…)](…)` never starts a match at the outer bracket — otherwise
            # `[^\]]*` would run across the `![…]` and match from the outer `[` down to
            # the inner `)`, consuming the image and leaving a dangling `](…)`. With
            # `[` excluded the outer bracket fails here and the inner image is deferred
            # on its own at the `!` trigger.
            LINK = /\G\[[^\[\]]{0,999}\]\(#{Base::LINK_GAP}#{URL}#{Base::LINK_TAIL}/
            private_constant :LINK

            BARE = /\G#{URL}/
            private_constant :BARE

            # Mirrors core's `Base62::KEYS`. A drift spec decodes sample tokens
            # through core's `Upload.sha1_from_base62_encoded` and compares.
            BASE62_KEYS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
            private_constant :BASE62_KEYS

            # Whether `raw` can contain a supported upload URL at all. This is
            # the cheap presence check for the {TierGate}: a body with only
            # unrelated `/uploads/` paths (WordPress and friends) does not
            # become a candidate.
            def self.candidate?(raw)
              return false unless raw.include?("uploads/")

              raw.include?("short-url/") || raw.include?("original/") || raw.include?("optimized/")
            end

            # Whether an engine href/src value has a supported upload shape.
            # The {EngineScanner} tracks upload values with this, so the filter
            # and the grammar that later anchors the construct cannot disagree.
            def self.tracked_value?(value)
              return false unless value.include?("uploads/")

              URL.match?(value)
            end

            # The 40-hex sha1 for a short-URL token, or nil when the token is
            # not a valid base62 sha1. Mirrors core's
            # `Upload.sha1_from_base62_encoded`.
            def self.sha1_from_short_token(token)
              value = 0
              token.each_char do |char|
                digit = BASE62_KEYS.index(char)
                return nil if digit.nil?

                value = value * 62 + digit
              end

              hex = value.to_s(16)
              hex.length > 40 ? nil : hex.rjust(40, "0")
            end

            def detect(input, pos, byte)
              case byte
              when 0x21 # `!`
                match_with(IMAGE, input, pos)
              when 0x5b # `[`
                match_with(LINK, input, pos)
              when 0x68, 0x48, 0x2f
                # 0x68 = `h`, 0x48 = `H`, 0x2f = `/`
                detect_bare(input, pos)
              end
            end

            private

            # A bare URL starts at a bare-URL boundary (line start, whitespace, or the
            # right kind of `(…)`; see {Boundaries#bare_url_boundary_before?}). A normal
            # `[text](url)` is consumed whole at its `[` trigger, so an inner URL is
            # only reached when the outer bracket wasn't a handled link — a nested
            # image `[![…](…)](url)` or an old lightbox, where rewriting the outer URL
            # in place is what we want.
            #
            # A relative upload URL is a link only at a `](…)` target; bare in prose it
            # stays plain text once cooked, so we leave it literal there. The match's
            # first bytes tell relative (`/…`) from absolute (`//host` or a scheme).
            def detect_bare(input, pos)
              return nil unless bare_url_boundary_before?(input, pos)

              match = match_at(BARE, input, pos)
              return nil unless match
              return nil if inadmissible_protocol_relative?(input, pos, match[0])
              return nil if relative_url?(match[0]) && !link_target_boundary_before?(input, pos)

              build_match(pos, match)
            end

            def match_with(pattern, input, pos)
              match = match_at(pattern, input, pos)
              match && build_match(pos, match)
            end

            def build_match(pos, match)
              sha1 = match[:sha1] || self.class.sha1_from_short_token(match[:short_token])
              return nil if sha1.nil?

              origin = match[:origin]
              host = origin && UrlOrigin.split(origin)&.first
              url = match[:upload_url]
              # The path part of the matched URL, for the ownership check
              # against a configured path prefix (see `UploadUrlReference`).
              rest = origin ? url.byteslice(origin.bytesize..) : url

              Match.new(
                start_pos: pos,
                end_pos: match.byteoffset(0).last,
                node: UploadUrlReference.new(sha1:, host:, rest:),
              )
            end

            # A relative URL starts with a single `/`; `//host` is protocol-relative
            # (absolute) and `https://…` schemed.
            def relative_url?(url)
              url.start_with?("/") && !url.start_with?("//")
            end
          end
        end
      end
    end
  end
end
