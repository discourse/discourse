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
            # The alt class excludes `[` so a nested image `![![…](…)](…)` can't be
            # matched from the outer `!` (see `UploadUrl::LINK` for the full why). The
            # trade-off: an alt with a lone unmatched `[` no longer matches, so that
            # upload stays a literal URL — nested-image safety wins over that rarer
            # shape.
            IMAGE_PATTERN =
              %r{\G!\[(?<alt>[^|\[\]]*)(?:\|(?<dimensions>[^\]]*))?\]\(upload://(?<url>[^)]+)\)}

            ATTACHMENT_PATTERN =
              %r{
              \G
              \[(?<filename>[^|\]]*)\|attachment\]
              \(upload://(?<url>[^)]+)\)
              (?:\s*\((?<size>[^)]+)\))?
            }xi

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

            # URL format: `sha1.ext` or just `sha1`. Returns `[sha1, filename-or-nil]`.
            def parse_upload_url(url_part)
              sha1, _, ext = url_part.partition(".")
              [sha1, ext.empty? ? nil : url_part]
            end
          end
        end
      end
    end
  end
end
