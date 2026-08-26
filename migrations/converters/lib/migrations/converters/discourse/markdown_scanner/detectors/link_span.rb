# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Detectors
          # Consumes a link without producing a node, so nothing inside one is
          # detected. Core applies mentions, hashtags and emoji through the
          # text-post-process engine (`discourse-markdown-it/src/features/
          # text-post-process.js`), which registers every rule with `skipAllLinks`:
          # `textReplace` refuses any text token with `linkLevel > 0`, and a link's
          # destination is not a text token at all. So `@bob` is a mention in prose
          # and plain text inside `https://elsewhere.example.com/@bob` — verified
          # against PrettyText, including the link text of `[hi @bob](…)`.
          #
          # That matters beyond fidelity: a mention detected inside a URL is replaced
          # by a placeholder, and the importer rewrites it to the destination's
          # (possibly renamed) username, silently corrupting somebody else's link.
          # A `https://mastodon.social/@user` link is the everyday case.
          #
          # This runs last, so a link the other detectors want — an internal link, an
          # upload URL — is still theirs. What reaches here is a link nothing else
          # claimed, and it passes through verbatim.
          class LinkSpan < Base
            TRIGGERS = ["!", "[", "h", "H", "/"].freeze

            URL_BODY = /[^#{Base::URL_TERMINATORS}]/
            private_constant :URL_BODY

            # The destination, plain or wrapped in angle brackets (`<…>`, which is how
            # CommonMark carries a destination containing spaces). Both runs are
            # capped: an uncapped run on a `)`-free body is re-scanned from every
            # opener, quadratically, and no real destination comes near the cap.
            DESTINATION = /(?:<[^<>\n]{0,2048}>|#{URL_BODY}{0,2048})/
            private_constant :DESTINATION

            # A markdown link or image, `[text](dest)`, with the optional title and
            # padding CommonMark allows: `[text](dest "title")`. The text takes one
            # level of balanced brackets but no nested link or image (see
            # `Base::LINK_TEXT`): a nested image `[![…](…)](…)` must not match at
            # the outer bracket, or the walk would never reach the inner upload and
            # it would go unrecorded.
            LINK = /\G!?\[#{Base::LINK_TEXT}\]\(#{Base::LINK_GAP}#{DESTINATION}#{Base::LINK_TAIL}/
            private_constant :LINK

            # A bare URL, schemed or protocol-relative, matched only where linkify
            # would make a link of it (see {Boundaries#bare_url_boundary_before?}).
            #
            # Unlike the other bare-URL patterns this doesn't trim trailing sentence
            # punctuation with a closing `\w`: the span is passed through unchanged
            # either way, so where it ends only decides where the walk resumes, and
            # anything trailing is punctuation that holds no construct.
            BARE = %r{\G(?:(?i:https?:)?//#{URL_BODY}{1,2048})}
            private_constant :BARE

            # What the walk reaches right after a `](`: the destination of a link
            # whose bracket no pattern took whole. Consumed even when relative,
            # unlike {BARE}: when the link forms in core nothing inside its
            # destination is detected, and when it doesn't, skipping a path
            # nobody's placeholder gets spliced into is the safe reading (see the
            # class comment for the corruption this avoids).
            DESTINATION_RUN = /\G#{URL_BODY}{1,2048}/
            private_constant :DESTINATION_RUN

            def detect(input, pos, byte)
              case byte
              when 0x21, 0x5b
                # 0x21 = `!`, 0x5b = `[`
                skip_at(pos, match_at(LINK, input, pos))
              when 0x68, 0x48, 0x2f
                # 0x68 = `h`, 0x48 = `H`, 0x2f = `/`
                detect_bare(input, pos)
              end
            end

            private

            def detect_bare(input, pos)
              if link_destination_before?(input, pos)
                return skip_at(pos, match_at(DESTINATION_RUN, input, pos))
              end

              return nil unless bare_url_boundary_before?(input, pos)

              match = match_at(BARE, input, pos)
              return nil if match.nil? || inadmissible_protocol_relative?(input, pos, match[0])

              skip_at(pos, match)
            end

            # A URL right after a `](` is a link destination, and when the link is
            # malformed — an unclosed title, a stray word after the destination —
            # core linkifies that URL instead. Either way it is inside a link and
            # nothing in it is detected, so this admits every `](`, unlike the
            # detectors that rewrite what they match and take only the `)](` shape.
            #
            # 0x28 = `(`, 0x5d = `]`
            def link_destination_before?(input, pos)
              pos >= 2 && input.getbyte(pos - 1) == 0x28 && input.getbyte(pos - 2) == 0x5d
            end

            # A node-less match: the {Scanner} appends the span as it stands and
            # resumes after it, without asking the caller for a replacement.
            def skip_at(pos, match)
              match && Match.new(start_pos: pos, end_pos: match.byteoffset(0).last, node: nil)
            end
          end
        end
      end
    end
  end
end
