# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Detectors
          # Detects a link pointing at another record on the *same* Discourse — a
          # topic, post, user, category, tag, group or badge — so the importer can
          # rewrite it once the id/slug maps exist. Two syntactic forms:
          #
          #   * a markdown link `[text](url)` (the text is captured), and
          #   * a bare, whitespace-delimited URL (kept bare, so the renderer emits a
          #     bare URL and oneboxes keep working).
          #
          # An image `![](…)` is not our concern, and a raw HTML `<a>` is out of scope
          # (as with the upload detector), so neither is matched.
          #
          # A URL qualifies when it is relative, or absolute with a host the caller
          # allowlisted (the source's base URL and any former domains). The host match
          # is scheme-insensitive, so `http://`, `https://` and protocol-relative
          # `//host` all count. Without a host set, only relative URLs qualify.
          #
          # The full original URL is kept (`url`) as the importer's fallback; the
          # route reveals the target, and everything after the route (further path,
          # query string, fragment) becomes the suffix, reattached verbatim at render.
          class InternalLink < Base
            TRIGGERS = ["[", "h", "/"].freeze

            # The route segments this detector understands, shared by the presence
            # gate and the bare-URL pattern.
            ROUTE_SEGMENT = "t|p|u|users|c|g|tags?|badges"
            private_constant :ROUTE_SEGMENT

            # Route segments that make a body worth scanning. OR'd into the scanner's
            # presence gate so a body with none of them skips the walk. Always wired,
            # since relative detection is unconditional.
            GATE = %r{/(?:#{ROUTE_SEGMENT})/}

            # A URL body: no whitespace, and none of the characters that close a
            # markdown link or delimit a bare URL. The trailing `\w` on the bare form
            # keeps a sentence's `.`/`,` after the URL out of the match (mirrors
            # `UploadUrl`).
            URL_BODY = /[^\s)"'<>]/
            private_constant :URL_BODY

            LINK = /\G\[(?<text>[^\]]*)\]\((?<url>#{URL_BODY}+)\)/
            private_constant :LINK

            # The bare form fires at every whitespace-preceded `h` and `/` the scanner
            # walks past, so it must reject ordinary words inside the regex engine —
            # an optional scheme+host, then a `/` and a route segment, before anything
            # is captured. A permissive capture-everything pattern here (with the
            # rejection left to `split_host`/`parse_route`) costs a MatchData and a
            # string per h-word of every scanned post, which is measurable across a
            # whole conversion.
            BARE = %r{\G(?<url>(?:(?:https?:)?//[^/\s)"'<>]+)?/(?:#{ROUTE_SEGMENT})/#{URL_BODY}*\w)}
            private_constant :BARE

            # Splits a URL into its host (nil when relative) and the rest (path, query
            # and fragment, starting at the first `/`). A protocol-relative `//host`
            # and an explicit `http(s)://host` both yield the host; a leading `/` (but
            # not `//`) is relative. Anything else (`mailto:`, `#anchor`, a bare word)
            # returns nil and isn't an internal link.
            SPLIT = %r{\A(?:(?:https?:)?//(?<host>[^/]+))?(?<rest>/[^\s]*)?\z}
            private_constant :SPLIT

            # A word segment matched the way the mention detector reads a username
            # (see `Base::WORD_PATTERN`): starts and ends on an alphanumeric/mark/`_`,
            # may hold `.`/`-` inside.
            WORD = /[\p{Alnum}\p{M}_](?:[\p{Alnum}\p{M}._-]*[\p{Alnum}\p{M}])?/
            private_constant :WORD

            # A single path segment, up to the next `/`, query `?` or fragment `#`.
            SEG = %r{[^/?#]+}
            private_constant :SEG

            # `/t/<id>` (topic) or `/t/<id>/<post_number>` (post by coordinates), the
            # id-only forms where the first `/t/` component is all digits.
            TOPIC_NUMERIC = %r{\A/t/(?<id>\d+)(?:/(?<pn>\d+))?(?=[/?#]|\z)}
            private_constant :TOPIC_NUMERIC

            # `/t/<slug>/<id>` (topic) or `/t/<slug>/<id>/<post_number>` (post by
            # coordinates). The slug is `-` for the slugless `/t/-/<id>` form.
            TOPIC_SLUG = %r{\A/t/#{SEG}/(?<id>\d+)(?:/(?<pn>\d+))?(?=[/?#]|\z)}
            private_constant :TOPIC_SLUG

            POST = %r{\A/p/(?<id>\d+)(?=[/?#]|\z)}
            private_constant :POST

            USER = %r{\A/u(?:sers)?/(?<name>#{WORD})}
            private_constant :USER

            # `/c/<slug-path>/<id>` (id wins) or the legacy `/c/<slug-path>`. The
            # segments are split in Ruby: a trailing all-digits segment is the id,
            # otherwise the segments join with `:` into a `parent:child` slug path.
            CATEGORY = %r{\A/c/(?<path>#{SEG}(?:/#{SEG})*)(?=[/?#]|\z)}
            private_constant :CATEGORY

            # `/tag/<name>` / `/tags/<name>`. The `(?!c/)` guard leaves the
            # `/tags/c/<category>/<tag>` intersection form undetected (out of scope).
            TAG = %r{\A/tags?/(?!c/)(?<name>#{SEG})}
            private_constant :TAG

            GROUP = %r{\A/g/(?<name>#{SEG})}
            private_constant :GROUP

            # `/badges/<id>` or `/badges/<id>/<slug>`; the slug is regenerated at
            # import, so it's consumed by the route rather than kept as suffix.
            BADGE = %r{\A/badges/(?<id>\d+)(?:/#{SEG})?(?=[/?#]|\z)}
            private_constant :BADGE

            # @param hosts [Set<String>, #include?] the source's own hosts (base URL
            #   plus former domains), already downcased. An absolute URL is internal
            #   only when its host is one of these. Empty means relative-only.
            # @param on_foreign_host [#call, nil] called with the host (a String)
            #   when an absolute URL is rejected for a foreign host but its path
            #   still parses as an internal route — the "did the operator forget a
            #   former domain?" signal. Nil skips the extra route parse of a foreign
            #   host, so a run that doesn't want the signal pays nothing beyond the
            #   cheap host rejection.
            def initialize(hosts: Set.new, on_foreign_host: nil)
              @hosts = hosts
              @on_foreign_host = on_foreign_host
            end

            def detect(input, pos, char)
              case char
              when "["
                detect_link(input, pos)
              when "h", "/"
                detect_bare(input, pos)
              end
            end

            private

            # A markdown link, unless it's the `]` of an image `![…](…)`, whose `[`
            # sits right after the `!`.
            def detect_link(input, pos)
              return nil if pos > 0 && input.getbyte(pos - 1) == 0x21 # `!`

              match = LINK.match(input, pos)
              return nil unless match

              build(input, pos, match, url: match[:url], text: match[:text])
            end

            # A bare URL is whitespace-delimited, so it must open the input or follow
            # whitespace — which also keeps it from firing on the URL inside a markdown
            # link's `(…)`, already handled by the link branch.
            def detect_bare(input, pos)
              return nil unless whitespace_before?(input, pos)

              match = BARE.match(input, pos)
              return nil unless match

              build(input, pos, match, url: match[:url], text: nil)
            end

            def build(input, pos, match, url:, text:)
              host, rest = split_host(url)
              return nil unless rest

              if host && !@hosts.include?(host)
                note_foreign_host(host, rest)
                return nil
              end

              target = parse_route(rest)
              return nil unless target

              suffix = rest[target[:route_length]..]

              node =
                InternalLinkReference.new(
                  url:,
                  text:,
                  target_type: target[:target_type],
                  target_id: target[:target_id],
                  target_name: target[:target_name],
                  target_topic_id: target[:target_topic_id],
                  target_post_number: target[:target_post_number],
                  target_suffix: suffix.empty? ? nil : suffix,
                )

              Match.new(start_pos: pos, end_pos: pos + match[0].length, node:)
            end

            # A foreign host is rejected before routing (the cheap check). Only when
            # a caller asked for the signal do we route-parse it, to tell an
            # internal-looking self-link on an unconfigured host from an ordinary
            # external link, and report the former.
            def note_foreign_host(host, rest)
              return unless @on_foreign_host

              @on_foreign_host.call(host) if parse_route(rest)
            end

            # @return [Array(String, String), nil] `[host, rest]` for an internal URL
            #   shape, else nil. `host` is nil for a relative URL; any port is dropped
            #   so it can be compared against the derived host set.
            def split_host(url)
              match = SPLIT.match(url)
              return nil unless match

              rest = match[:rest]
              return nil if rest.nil? # `//host` with no path is nothing we route

              host = match[:host]&.sub(/:\d+\z/, "")&.downcase
              [host, rest]
            end

            # Matches `rest` (the path onwards) against the known routes in turn.
            # Returns the target fields plus `route_length` (how much of `rest` the
            # route consumed; the remainder is the suffix), or nil for an unknown path.
            def parse_route(rest)
              topic_or_post(rest) || post_by_id(rest) || user(rest) || category(rest) ||
                tag(rest) || group(rest) || badge(rest)
            end

            def topic_or_post(rest)
              match = TOPIC_NUMERIC.match(rest) || TOPIC_SLUG.match(rest)
              return nil unless match

              if match[:pn]
                target(
                  match,
                  :post,
                  target_topic_id: match[:id].to_i,
                  target_post_number: match[:pn].to_i,
                )
              else
                target(match, :topic, target_id: match[:id].to_i)
              end
            end

            def post_by_id(rest)
              match = POST.match(rest)
              match && target(match, :post, target_id: match[:id].to_i)
            end

            def user(rest)
              match = USER.match(rest)
              match && target(match, :user, target_name: match[:name])
            end

            def category(rest)
              match = CATEGORY.match(rest)
              return nil unless match

              segments = match[:path].split("/")
              if segments.last.match?(/\A\d+\z/)
                target(match, :category, target_id: segments.last.to_i)
              else
                target(match, :category, target_name: segments.join(":"))
              end
            end

            def tag(rest)
              match = TAG.match(rest)
              match && target(match, :tag, target_name: match[:name])
            end

            def group(rest)
              match = GROUP.match(rest)
              match && target(match, :group, target_name: match[:name])
            end

            def badge(rest)
              match = BADGE.match(rest)
              match && target(match, :badge, target_id: match[:id].to_i)
            end

            def target(
              match,
              target_type,
              target_id: nil,
              target_name: nil,
              target_topic_id: nil,
              target_post_number: nil
            )
              {
                target_type:,
                target_id:,
                target_name:,
                target_topic_id:,
                target_post_number:,
                route_length: match[0].length,
              }
            end
          end
        end
      end
    end
  end
end
