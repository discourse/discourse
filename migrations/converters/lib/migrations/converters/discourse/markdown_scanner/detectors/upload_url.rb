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
          # and absolute (http/https and protocol-relative) forms are recognized.
          #
          # Recognition is deliberately permissive and does no host allowlisting: a URL
          # that looks like an upload but points at some other forum still resolves to
          # nothing at import and comes back verbatim (see `UploadUrlReference`), so
          # there's no risk in matching it here.
          class UploadUrl < Base
            TRIGGERS = ["!", "[", "h", "/"].freeze

            # A full upload URL, from an optional scheme/host down to the sha1 at the
            # start of the basename. `[^/#{Base::URL_BODY_SOURCE}]` is a path-segment
            # character (a URL-body character minus the slash; see
            # `Base::URL_BODY_SOURCE`). The trailing `\w` keeps a sentence's `.`/`,`
            # after a bare URL out of the match.
            URL =
              %r{
                (?: (?:https?:)? // [^/#{Base::URL_BODY_SOURCE}]+ )?   # optional scheme + host
                (?: / [^/#{Base::URL_BODY_SOURCE}]+ )*?                # optional leading path (subfolder installs)
                / (?:secure-)? uploads /
                (?: [^/#{Base::URL_BODY_SOURCE}]+ / )*?                # site name and any segments before original/
                (?: original | optimized ) /
                (?: [^/#{Base::URL_BODY_SOURCE}]+ / )*                 # depth/partition segments (2X/a/ab/ …)
                (?<sha1> \h{40} ) (?=[._])                             # sha1, then the extension or `_WxH` suffix
                [^#{Base::URL_BODY_SOURCE}]* \w
              }x
            private_constant :URL

            # `\G` anchors each match at `pos` so scanning stays linear.
            IMAGE = /\G!\[[^\]]*\]\(#{URL}\)/
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
            def detect_bare(input, pos)
              return nil unless bare_url_boundary_before?(input, pos)
              match_with(BARE, input, pos)
            end

            def match_with(pattern, input, pos)
              match = match_at(pattern, input, pos)
              return nil unless match

              Match.new(
                start_pos: pos,
                end_pos: match.byteoffset(0).last,
                node: UploadUrlReference.new(sha1: match[:sha1], original_markdown: match[0]),
              )
            end
          end
        end
      end
    end
  end
end
