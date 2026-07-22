# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Detectors
          # Detects uploads referenced by a full URL instead of a short `upload://`
          # one — markdown images `![alt](url)`, markdown links `[text](url)` and
          # bare whitespace-delimited URLs. The URL must carry an `/uploads/` or
          # `/secure-uploads/` segment with an `original/` or `optimized/` path below
          # it, and its basename must start with the upload's 40-hex sha1 (Discourse's
          # filename convention; see core's `Upload` and `FileStore`). Both relative
          # and absolute (http/https and protocol-relative) forms are recognized in
          # image and link syntax. A bare URL follows the same rule as an internal
          # link: an absolute bare URL is recognized in prose, a relative one only at
          # a `](…)` link target — a relative path bare in prose stays plain text once
          # cooked, so rewriting it would turn text into a link.
          #
          # Recognition is deliberately permissive and does no host allowlisting: a URL
          # that looks like an upload but points at some other forum still resolves to
          # nothing at import and comes back verbatim (see `UploadUrlReference`), so
          # there's no risk in matching it here.
          class UploadUrl < Base
            TRIGGERS = ["!", "[", "h", "/"].freeze

            # A full upload URL, from an optional scheme/host down to the sha1 at the
            # start of the basename. `[^/#{Base::URL_TERMINATORS}]` is a path-segment
            # character (a URL-body character minus the slash; see
            # `Base::URL_TERMINATORS`). The trailing `\w` keeps a sentence's `.`/`,`
            # after a bare URL out of the match.
            URL =
              %r{
                (?: (?:https?:)? // [^/#{Base::URL_TERMINATORS}]+ )?   # optional scheme + host
                (?: / [^/#{Base::URL_TERMINATORS}]+ )*?                # optional leading path (subfolder installs)
                / (?:secure-)? uploads /
                (?: [^/#{Base::URL_TERMINATORS}]+ / )*?                # site name and any segments before original/
                (?: original | optimized ) /
                (?: [^/#{Base::URL_TERMINATORS}]+ / )*                 # depth/partition segments (2X/a/ab/ …)
                (?<sha1> \h{40} ) (?=[._])                             # sha1, then the extension or `_WxH` suffix
                [^#{Base::URL_TERMINATORS}]* \w
              }x
            private_constant :URL

            # `\G` anchors each match at `pos` so scanning stays linear. The alt
            # class excludes `[` for the same reason as `LINK` below: a nested image
            # `![![…](…)](…)` must not match from the outer `!`.
            IMAGE = /\G!\[[^\[\]]*\]\(#{URL}\)/
            private_constant :IMAGE

            # The text class excludes `[` so the `[` of a nested image
            # `[![…](…)](…)` never starts a match at the outer bracket — otherwise
            # `[^\]]*` would run across the `![…]` and match from the outer `[` down to
            # the inner `)`, swallowing the image and leaving a dangling `](…)`. With
            # `[` excluded the outer bracket fails here and the inner image is deferred
            # on its own at the `!` trigger.
            LINK = /\G\[[^\[\]]*\]\(#{URL}\)/
            private_constant :LINK

            BARE = /\G#{URL}/
            private_constant :BARE

            def detect(input, pos, byte)
              case byte
              when 0x21 # `!`
                match_with(IMAGE, input, pos)
              when 0x5b # `[`
                match_with(LINK, input, pos)
              when 0x68, 0x2f
                # 0x68 = `h`, 0x2f = `/`
                detect_bare(input, pos)
              end
            end

            private

            # A bare URL starts at a bare-URL boundary (line start, whitespace, or the
            # right kind of `(…)`; see {Base#bare_url_boundary_before?}). A normal
            # `[text](url)` is consumed whole at its `[` trigger, so the walk reaches an
            # inner URL only when the outer bracket wasn't a handled link — a nested
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
              return nil if relative_url?(match[0]) && !link_target_boundary_before?(input, pos)

              build_match(pos, match)
            end

            def match_with(pattern, input, pos)
              match = match_at(pattern, input, pos)
              match && build_match(pos, match)
            end

            def build_match(pos, match)
              Match.new(
                start_pos: pos,
                end_pos: match.byteoffset(0).last,
                node: UploadUrlReference.new(sha1: match[:sha1], original_markdown: match[0]),
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
