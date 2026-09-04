# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Constructs
          # Detects a link pointing at another record on the *same* Discourse —
          # a topic, post, user, category, tag, group or badge — so the importer
          # can rewrite it once the id/slug maps exist, either as a markdown
          # link `[text](url)` or as a bare URL (kept bare, so oneboxes keep
          # working).
          #
          # Raw HTML anchors are out of scope: markdown-it exposes an entire raw
          # tag as an opaque HTML token, not as a link with an href, so
          # rewriting one safely needs an HTML attribute parser. So is
          # `/filter?q=…`, which names its categories and tags in the query
          # string rather than the path.
          #
          # An absolute URL qualifies when its host is one the caller
          # allowlisted, scheme-insensitively, and its path sits inside that
          # host's prefix (see {UrlOrigin}). A relative URL qualifies only where
          # it is actually a link (see `Base#detect_bare_url`). A bare URL with
          # no scheme at all (`forum.example.com/t/5`), which core's linkify
          # also links, contains no character a construct can trigger on, so the
          # engine tier rewrites that form in place instead.
          class InternalLink < Base
            TRIGGERS = ["!", "[", "h", "H", "/"].freeze

            # The route segments this construct understands, shared by the
            # presence gate and the bare-URL pattern.
            ROUTE_SEGMENT = "t|p|u|users|c|category|g|groups?|tags?|badges"
            private_constant :ROUTE_SEGMENT

            # A relative link (`/t/5`) contains no character of the gate's
            # built-in presence check, so route segments contribute their own.
            ROUTE_PRESENCE = %r{/(?:#{ROUTE_SEGMENT})/}
            private_constant :ROUTE_PRESENCE

            # A URL-body character (see `Base::URL_TERMINATORS`). The trailing
            # `\w` on the bare form keeps a sentence's `.`/`,` out of the match.
            URL_BODY = /[^#{Base::URL_TERMINATORS}]/
            private_constant :URL_BODY

            # A URL-body character outside a parenthesis, for the destination
            # runs below.
            DESTINATION_BODY = /[^(#{Base::URL_TERMINATORS}]/
            private_constant :DESTINATION_BODY

            # A destination, with the one level of balanced parentheses
            # CommonMark allows (`/search?q=(oauth2_basic)%20x`). The balanced
            # pair is tried before a lone `(`, which still ends up in the
            # destination the way it did before the pair was allowed. Every run
            # is capped and atomic, so a `(` that never closes is scanned once
            # (see the ReDoS note in `Base`).
            DESTINATION =
              /(?>(?:#{DESTINATION_BODY}{1,255}|\((?>#{DESTINATION_BODY}{0,255})\)|\(){1,32})/
            private_constant :DESTINATION

            # The destination takes the padding, optional title and `<…>` form
            # CommonMark allows (see `Base::LINK_TAIL`), or an internal link
            # written with a title would keep pointing at the source site. The
            # `<…>` alternative repeats the `url` group name, which Ruby allows.
            LINK_SYNTAX =
              /\[(?<text>#{Base::LINK_TEXT})\]\(#{Base::LINK_GAP}(?:<(?<url>[^<>\n]{1,2048})>|(?<url>#{DESTINATION}))#{Base::LINK_TAIL}/
            private_constant :LINK_SYNTAX

            LINK = /\G#{LINK_SYNTAX}/
            private_constant :LINK

            # An image whose source is an internal URL — an avatar, an emoji
            # sprite, a hotlinked screenshot of another topic. Core rewrites
            # nothing about it, but its origin (and any route in its path) has
            # to move to the destination site like a link's does, so the whole
            # `![alt](src)` is recorded with the alt text as the label.
            IMAGE = /\G!#{LINK_SYNTAX}/
            private_constant :IMAGE

            # The bare form fires at every whitespace-preceded `h` and `/` the
            # scanner walks past, so it must reject ordinary words inside the
            # regex engine: a permissive capture-everything pattern would cost a
            # MatchData and a string per h-word of every scanned post. Each
            # branch therefore starts with something an ordinary word fails on —
            # here the `//`, since every path on a configured host belongs to
            # the forum. There need be no path at all (`https://host` is the
            # front page), so the host and everything after it are one run,
            # ending on a word character — which keeps a sentence's `.` outside
            # the URL — or on a `/`, for the root path.
            #
            # The scheme is case-insensitive because linkify-it reads it that
            # way. The insensitivity stops there: Rails routing is
            # case-sensitive, so `/T/5` is not a topic on the destination
            # either.
            ABSOLUTE = %r{(?:(?i:https?:)?//#{URL_BODY}{0,2048}[\w/])}
            private_constant :ABSOLUTE

            # A relative URL has no host to reject on, and detection is tried at
            # every `/` in prose (`and/or`, `50/50`), so a route segment is what
            # tells a link apart from a slash. The lazy `(?:/…)*?` admits a
            # subfolder install's leading segments and demands a route segment
            # after, so a plain `/` fails without the group ever expanding.
            RELATIVE =
              %r{(?:/[^/#{Base::URL_TERMINATORS}]{1,255}){0,16}?/(?:#{ROUTE_SEGMENT})/#{URL_BODY}{0,2048}\w}
            private_constant :RELATIVE

            BARE = /\G(?<url>#{ABSOLUTE}|#{RELATIVE})/
            private_constant :BARE

            # @param hosts [Hash{String => (String, nil)}] the source's own
            #   hosts, each downcased and mapped to its path prefix. Empty means
            #   relative-only.
            # @param base_prefix [String, nil] the current site's own path
            #   prefix. It is stripped from a relative link before the route is
            #   parsed.
            # @param on_foreign_host [#call, nil] called with the host when an
            #   absolute URL is rejected for a foreign host but its path still
            #   parses as an internal route — the "did the operator forget a
            #   former domain?" signal. The foreign path is parsed as-is, so a
            #   forgotten domain that served the forum under a subdirectory
            #   parses no route and stays unreported.
            def initialize(hosts: {}, base_prefix: nil, on_foreign_host: nil)
              @hosts = hosts
              @base_prefix = base_prefix
              @reported_foreign_hosts = Set.new
              @on_foreign_host = on_foreign_host
              @presence_pattern = build_presence_pattern
            end

            attr_reader :presence_pattern

            def detect(input, pos, byte)
              case byte
              when 0x21 # `!`
                detect_image(input, pos)
              when 0x5b # `[`
                detect_link(input, pos)
              when 0x68, 0x48, 0x2f
                # 0x68 = `h`, 0x48 = `H`, 0x2f = `/`
                detect_bare(input, pos)
              end
            end

            # For the engine tier, which filters URL values before any construct
            # runs and so never reaches `build` for a foreign link.
            def note_foreign_url(url)
              origin = classify(url)
              note_foreign_host(origin.host, origin.rest) if origin&.foreign
            end

            # For a URL whose position the engine tier already confirmed but
            # whose surrounding bytes are the URL itself. `route_url` is the
            # engine's normalized href, so it only resolves the host and its
            # prefix — the route and the stored suffix are read from `url`, the
            # raw spelling.
            def reference_for(route_url:, url:)
              origin = classify(route_url)
              return nil if origin.nil? || origin.foreign

              rest = raw_rest(url)
              return nil if rest.nil?

              path = UrlOrigin.path_within_prefix(rest, origin.prefix)
              return nil if path.nil?

              route_or_site_node(
                url:,
                text: nil,
                path:,
                host: origin.host,
                url_offset: 0,
                label_url_offset: nil,
              )
            end

            private

            def classify(url)
              UrlOrigin.classify(url, hosts: @hosts, base_prefix: @base_prefix)
            end

            # A route-less absolute URL (`https://host/faq`) carries no route
            # segment, so without an alternative here a post holding nothing
            # else would classify `:none` and keep pointing at the old origin.
            # The hosts do the gating themselves, far more selectively than `//`
            # would.
            #
            # Each host gets its own case-insensitive alternative. Wrapping a
            # `Regexp.union` of them in one `/i` does not work: union serializes
            # what it is given as `(?-mix:…)`, turning the flag back off inside
            # its scope.
            def build_presence_pattern
              return ROUTE_PRESENCE if @hosts.empty?

              Regexp.union(ROUTE_PRESENCE, *@hosts.keys.map { |host| /#{Regexp.escape(host)}/i })
            end

            # A markdown link, unless it's the `[` of an image `![…](…)`, which
            # {#detect_image} takes whole at the `!`.
            def detect_link(input, pos)
              return nil if bang_before?(input, pos)

              match = match_at(LINK, input, pos)
              return nil unless match

              build(pos, match, url: match[:url], text: match[:text])
            end

            def detect_image(input, pos)
              match = match_at(IMAGE, input, pos)
              return nil unless match

              build(pos, match, url: match[:url], text: match[:text])
            end

            # The destination's byte offset within the matched construct, and —
            # when the label spells the destination too (a `[url](url)`
            # self-link) — that spelling's offset. The importer rewrites exactly
            # these spans, so a URL the author repeated in a link title stays
            # the author's text. An ambiguous label records no label span.
            def destination_spans(pos, match, url)
              url_offset = match.byteoffset(:url).first - pos

              label_offset = nil
              # The bare pattern has no text group at all, so guard by name.
              if match.names.include?("text") && (text = match[:text])
                index = text.byteindex(url)
                if index && text.byteindex(url, index + 1).nil?
                  label_offset = (match.byteoffset(:text).first - pos) + index
                end
              end

              [url_offset, label_offset]
            end

            def detect_bare(input, pos)
              detect_bare_url(input, pos, BARE) do |match|
                build(pos, match, url: match[:url], text: nil)
              end
            end

            def build(pos, match, url:, text:)
              origin = classify(url)
              return nil if origin.nil?

              if origin.foreign
                note_foreign_host(origin.host, origin.rest)
                return nil
              end

              # A sibling app's path outside the prefix stays literal — no
              # route, no `:site` rewrite, no signal.
              return nil if origin.path.nil?

              url_offset, label_url_offset = destination_spans(pos, match, url)
              node =
                route_or_site_node(
                  url:,
                  text:,
                  path: origin.path,
                  host: origin.host,
                  url_offset:,
                  label_url_offset:,
                )
              return nil unless node

              Match.new(start_pos: pos, end_pos: match.byteoffset(0).last, node:)
            end

            # A bare schemeless domain starts with its host, so the part from
            # the first `/`, `?` or `#` on is the path (a bare domain with no
            # path is the front page: an empty rest).
            def raw_rest(url)
              host, rest = UrlOrigin.split(url)
              return rest unless host.nil? && rest.nil?

              start = url.index(%r{[/?\#]})
              start.nil? ? "" : url[start..]
            end

            # A resolved route builds a typed target; an absolute internal URL
            # with no route builds a `:site` target, whose origin alone is
            # rewritten. Two cases stay literal: a relative route-less URL,
            # already correct on the destination, and a coordinate-shaped path
            # that failed to parse (see `RouteParser.coordinate_shaped?`).
            def route_or_site_node(url:, text:, path:, host:, url_offset:, label_url_offset:)
              if (target = RouteParser.parse(path))
                # `path` is the extracted URL's own string (character domain),
                # so the suffix is a plain character slice — only the `Match`
                # positions are byte offsets.
                target_reference(
                  url:,
                  text:,
                  target:,
                  suffix: path[target[:route_length]..],
                  url_offset:,
                  label_url_offset:,
                )
              elsif host && !RouteParser.coordinate_shaped?(path)
                target_reference(
                  url:,
                  text:,
                  target: SITE_TARGET,
                  suffix: path,
                  url_offset:,
                  label_url_offset:,
                )
              end
            end

            # A `:site` target rewrites only the origin, so it names no record.
            SITE_TARGET = {
              target_type: :site,
              target_id: nil,
              target_name: nil,
              target_topic_id: nil,
              target_post_number: nil,
              target_tag_path: nil,
            }.freeze
            private_constant :SITE_TARGET

            def target_reference(url:, text:, target:, suffix:, url_offset:, label_url_offset:)
              InternalLinkReference.new(
                url:,
                text:,
                target_type: target[:target_type],
                target_id: target[:target_id],
                target_name: target[:target_name],
                target_topic_id: target[:target_topic_id],
                target_post_number: target[:target_post_number],
                target_tag_path: target[:target_tag_path],
                target_suffix: suffix.presence,
                url_offset:,
                label_url_offset:,
              )
            end

            # A foreign host is rejected before routing (the cheap check); only
            # a caller that asked for the signal pays for the route parse that
            # tells an internal-looking self-link on an unconfigured host from
            # an ordinary external link. Once per host: a forgotten former
            # domain can appear in millions of posts, and the signal's value is
            # the host name.
            def note_foreign_host(host, rest)
              return if @on_foreign_host.nil? || @reported_foreign_hosts.include?(host)
              return unless RouteParser.parse(rest)

              @reported_foreign_hosts << host
              @on_foreign_host.call(host)
            end
          end
        end
      end
    end
  end
end
