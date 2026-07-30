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

            # A markdown link or image. The text class excludes `[` for the same
            # reason as `UploadUrl::LINK`: a nested image `[![…](…)](…)` must not
            # match at the outer bracket, or the walk would never reach the inner
            # upload and it would go unrecorded.
            LINK = /\G!?\[[^\[\]]*\]\(#{URL_BODY}*\)/
            private_constant :LINK

            # A bare URL, schemed or protocol-relative, matched only where linkify
            # would make a link of it (see {Base#bare_url_boundary_before?}).
            #
            # Unlike the other bare-URL patterns this doesn't trim trailing sentence
            # punctuation with a closing `\w`: the span is passed through unchanged
            # either way, so where it ends only decides where the walk resumes, and
            # anything trailing is punctuation that holds no construct.
            BARE = %r{\G(?:(?i:https?:)?//#{URL_BODY}+)}
            private_constant :BARE

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
              return nil unless bare_url_boundary_before?(input, pos)

              match = match_at(BARE, input, pos)
              return nil if match.nil? || inadmissible_protocol_relative?(input, pos, match[0])

              skip_at(pos, match)
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
