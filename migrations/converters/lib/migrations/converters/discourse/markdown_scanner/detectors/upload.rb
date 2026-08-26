# frozen_string_literal: true

require "markbridge"

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Detectors
          # Detects Discourse upload references (`upload://` URLs), both
          # `![alt|dims](upload://sha1.ext)` images and
          # `[file|attachment](upload://sha1.ext) (size)` attachments.
          class Upload < Base
            TRIGGERS = ["!", "["].freeze

            # `\G` anchors each match at `pos` so we match in place rather than
            # slicing the tail of the input on every `!`/`[`.
            #
            # The alt and dimensions classes exclude `[` so a nested image
            # `![![…](…)](…)` can't be matched from the outer `!` (see
            # `UploadUrl::LINK` for the full why), and so an unmatched `[` before
            # the real construct can't pull the match start left — core's label
            # parse fails on it and renders from the inner bracket instead. The
            # trade-off: an alt with a lone unmatched `[` no longer matches, so
            # that upload stays a literal URL — nested-image safety wins over that
            # rarer shape.
            # The alt cap is CommonMark's own 999-character link-label limit; the
            # URL and dimensions classes exclude the newline (a destination cannot
            # contain an unescaped line end) and are capped, so a body full of
            # unclosed openers cannot make every `!` re-scan the whole tail.
            IMAGE_PATTERN =
              %r{\G!\[(?<alt>[^|\[\]]{0,999})(?:\|(?<dimensions>[^\[\]\n]{0,99}))?\]\(upload://(?<url>[^)\n]{1,512})\)}

            # The marker folds case but the scheme does not, which is core's own
            # split: `[r.pdf|ATTACHMENT](upload://…)` still cooks a link carrying
            # `data-orig-href`, so the upload is real and has to be recorded, while
            # `UPLOAD://` cooks a link with no `data-orig-href` at all — nothing the
            # importer could resolve, and matching it would replace text core left
            # alone. Hence `/i` on the pattern with the scheme opted out.
            ATTACHMENT_PATTERN =
              %r{
              \G
              # The filename class excludes `[` like the alt above: an unmatched
              # `[` earlier on the line must not start the match, or the literal
              # text before the real `[file|attachment]` would be swallowed into
              # the filename and dropped at re-render.
              \[(?<filename>[^|\[\]]{0,999})\|attachment\]
              \((?-i:upload)://(?<url>[^)\n]{1,512})\)
              # Discourse writes the size right after the link, on the same line.
              # `\s*` here would let the group cross a line end — even a blank one —
              # and swallow a following parenthesized line into the match. Only the
              # sha1 is recorded, so the importer re-renders the attachment from the
              # destination's metadata and everything else the match covered is
              # dropped from the post.
              (?:[^\S\n]*\((?<size>[^)\n]{1,99})\))?
            }xi
            private_constant :IMAGE_PATTERN, :ATTACHMENT_PATTERN

            def detect(input, pos, byte)
              case byte
              when 0x21 # `!`
                detect_image(input, pos)
              when 0x5b # `[`
                detect_attachment(input, pos)
              end
            end

            private

            def detect_image(input, pos)
              match = match_at(IMAGE_PATTERN, input, pos)
              return nil unless match

              sha1, filename = parse_upload_url(match[:url])
              alt = match[:alt]
              alt = nil if alt.empty?

              node =
                Markbridge::AST::Upload.new(
                  sha1:,
                  filename:,
                  alt:,
                  dimensions: match[:dimensions],
                  raw: match[0],
                )

              Match.new(start_pos: pos, end_pos: match.byteoffset(0).last, node:)
            end

            def detect_attachment(input, pos)
              match = match_at(ATTACHMENT_PATTERN, input, pos)
              return nil unless match

              sha1, = parse_upload_url(match[:url])

              node =
                Markbridge::AST::Upload.new(
                  sha1:,
                  filename: match[:filename],
                  type: :attachment,
                  size: match[:size],
                  raw: match[0],
                )

              Match.new(start_pos: pos, end_pos: match.byteoffset(0).last, node:)
            end

            # URL format: `sha1.ext` or just `sha1`. Returns the sha1 and the
            # filename, which is the full `sha1.ext` string (nil without extension).
            def parse_upload_url(url_part)
              sha1, _, rest = url_part.partition(".")
              [sha1, rest.empty? ? nil : url_part]
            end
          end
        end
      end
    end
  end
end
