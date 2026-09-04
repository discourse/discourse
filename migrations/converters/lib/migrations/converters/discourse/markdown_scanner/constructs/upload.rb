# frozen_string_literal: true

require "markbridge"

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Constructs
          # Detects Discourse upload references (`upload://` URLs):
          # `![alt|dims](upload://sha1.ext)` images,
          # `[file|attachment](upload://sha1.ext) (size)` attachments,
          # `[label|meta](upload://sha1.ext)` link-position labels with pipe
          # metadata (failed image pastes), and plain
          # `[label](upload://sha1.ext)` links.
          class Upload < Base
            TRIGGERS = ["!", "["].freeze

            # Like `Base::LINK_TEXT`, but with `|` kept out of the plain runs:
            # the label ends at the pipe that starts the metadata
            # (`[Juan [John] Hernandez.pdf|attachment]`). Line ends stay in,
            # as in core: an AI-captioned image carries its caption on a line
            # of its own inside the alt.
            LABEL = /(?>[^|\[\]]{0,999}(?:\[[^\[\]]{0,999}\](?!\()[^|\[\]]{0,999}){0,32})/
            private_constant :LABEL

            # The URL and dimensions classes exclude the newline (a destination
            # cannot contain an unescaped line end) and are capped.
            IMAGE_PATTERN =
              %r{\G!\[(?<alt>#{LABEL})(?:\|(?<dimensions>[^\[\]\n]{0,99}))?\]\(upload://(?<url>[^)\n]{1,512})\)}

            # The marker folds case but the scheme does not, which is core's own
            # split: `[r.pdf|ATTACHMENT](upload://…)` still cooks a link
            # carrying `data-orig-href`, while `UPLOAD://` cooks one with no
            # `data-orig-href` at all — nothing the importer could resolve.
            ATTACHMENT_PATTERN =
              %r{
              \G
              \[(?<filename>#{LABEL})\|attachment\]
              \((?-i:upload)://(?<url>[^)\n]{1,512})\)
              # `\s*` here would let the group cross a line end — even a blank
              # one — and pull a following parenthesized line into the match.
              (?:[^\S\n]*\((?<size>[^)\n]{1,99})\))?
            }xi
            # A link-position label with metadata after a pipe —
            # `[image|281x500](upload://sha1.ext)` — the leftover of a failed
            # image paste. Core renders the label literally, pipe and all, as a
            # plain link to the upload, so the upload is as real as in any other
            # form. The suffix class allows pipes, so `[a|b|c]` matches whole;
            # an exact `|attachment` marker belongs to ATTACHMENT_PATTERN above.
            LINK_PATTERN =
              %r{
              \G
              \[(?<filename>#{LABEL})\|(?!attachment\])[^\[\]\n]{0,99}\]
              \((?-i:upload)://(?<url>[^)\n]{1,512})\)
            }xi
            # A plain `[label](upload://sha1.ext)` link, which core links the
            # same way.
            PLAIN_LINK_PATTERN =
              %r{
              \G
              \[(?<filename>#{LABEL})\]
              \((?-i:upload)://(?<url>[^)\n]{1,512})\)
            }xi
            private_constant :IMAGE_PATTERN, :ATTACHMENT_PATTERN, :LINK_PATTERN, :PLAIN_LINK_PATTERN

            # The `upload://` form on its own, with no `![…](…)` around it: a
            # reference definition's destination, which the engine tier
            # confirmed as an image's or a link's source.
            SHORT_URL = %r{\Aupload://(?<url>[^\s)]{1,512})\z}
            private_constant :SHORT_URL

            def detect(input, pos, byte)
              case byte
              when 0x21 # `!`
                detect_image(input, pos)
              when 0x5b # `[`
                detect_attachment(input, pos) || detect_link(input, pos) ||
                  detect_plain_link(input, pos)
              end
            end

            # The node for a bare {SHORT_URL} spelling, whose whole span is the
            # URL itself — the alt text and the dimensions live in the
            # `![alt][id]` that uses the definition and stay there.
            #
            # @return [Markbridge::AST::Upload, nil]
            def reference_for(url)
              match = SHORT_URL.match(url)
              return nil unless match

              sha1, filename = parse_upload_url(match[:url])
              Markbridge::AST::Upload.new(sha1:, filename:, raw: url)
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

            # Only the sha1 and the verbatim source reach the embed row: a
            # resolution hit re-renders the attachment from the destination's
            # metadata, a miss restores the label untouched.
            def detect_link(input, pos)
              build_link(pos, match_at(LINK_PATTERN, input, pos))
            end

            def detect_plain_link(input, pos)
              build_link(pos, match_at(PLAIN_LINK_PATTERN, input, pos))
            end

            def build_link(pos, match)
              return nil unless match

              sha1, = parse_upload_url(match[:url])

              node =
                Markbridge::AST::Upload.new(
                  sha1:,
                  filename: match[:filename],
                  type: :attachment,
                  raw: match[0],
                )

              Match.new(start_pos: pos, end_pos: match.byteoffset(0).last, node:)
            end

            # URL format: `sha1.ext` or just `sha1`. The filename is the full
            # `sha1.ext` string, nil without an extension.
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
