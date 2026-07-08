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
          # Recognition is deliberately greedy and does no host allowlisting: a URL
          # that looks like an upload but points at some other forum still resolves to
          # nothing at import and comes back verbatim (see `UploadUrlReference`), so
          # there's no risk in matching it here.
          class UploadUrl < Base
            TRIGGERS = ["!", "[", "h", "/"].freeze

            # A full upload URL, from an optional scheme/host down to the sha1 at the
            # start of the basename. `[^/\s)"'<>]` is a path-segment character: not a
            # slash, whitespace, closing paren (a markdown link's terminator) or a
            # quote/angle bracket. The trailing `\w` keeps a sentence's `.`/`,` after
            # a bare URL out of the match.
            URL = Regexp.new(<<~'REGEX', Regexp::EXTENDED)
                (?: (?:https?:)? // [^/\s)"'<>]+ )?   # optional scheme + host
                (?: / [^/\s)"'<>]+ )*?                # optional leading path (subfolder installs)
                / (?:secure-)? uploads /
                (?: [^/\s)"'<>]+ / )*?                # site name and any segments before original/
                (?: original | optimized ) /
                (?: [^/\s)"'<>]+ / )*                 # depth/partition segments (2X/a/ab/ …)
                (?<sha1> \h{40} ) (?=[._])            # sha1, then the extension or `_WxH` suffix
                [^\s)"'<>]* \w
              REGEX
            private_constant :URL

            # `\G` anchors each match at `pos` so scanning stays linear.
            IMAGE = /\G!\[[^\]]*\]\(#{URL}\)/
            private_constant :IMAGE

            LINK = /\G\[[^\]]*\]\(#{URL}\)/
            private_constant :LINK

            BARE = /\G#{URL}/
            private_constant :BARE

            def detect(input, pos, char)
              case char
              when "!"
                match_with(IMAGE, input, pos)
              when "["
                match_with(LINK, input, pos)
              when "h", "/"
                detect_bare(input, pos)
              end
            end

            private

            # A bare URL is whitespace-delimited, so it must start the line or follow
            # whitespace. This also keeps it from firing on a URL sitting inside a
            # markdown link's `(…)`, which the link/image branches already handle.
            def detect_bare(input, pos)
              return nil unless whitespace_before?(input, pos)
              match_with(BARE, input, pos)
            end

            def match_with(pattern, input, pos)
              match = pattern.match(input, pos)
              return nil unless match

              Match.new(
                start_pos: pos,
                end_pos: pos + match[0].length,
                node: UploadUrlReference.new(sha1: match[:sha1], original_markdown: match[0]),
              )
            end
          end
        end
      end
    end
  end
end
