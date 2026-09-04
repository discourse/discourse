# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Constructs
          # Detects a link pointing at another record on the *same* Discourse — a
          # topic, post, user, category, tag, group or badge — so the importer can
          # rewrite it once the id/slug maps exist. Two syntactic forms:
          #
          #   * a markdown link `[text](url)` (the text is captured), and
          #   * a bare, whitespace-delimited URL (kept bare, so the renderer emits a
          #     bare URL and oneboxes keep working).
          #
          # An image `![](…)` is not our concern. Raw HTML anchors are not matched
          # either: markdown-it exposes an entire raw tag as an opaque HTML token,
          # not as a link with an href. Rewriting those safely needs a separate HTML
          # attribute parser that can preserve the attribute's exact source spelling;
          # the URL constructs only locate links and images the engine reports
          # semantically.
          #
          # `/filter?q=…` is out of scope too, and deliberately so: it names its
          # categories and tags inside the query string rather than in the path
          # (`list#filter`, `config/routes.rb`), so rewriting one means parsing and
          # rebuilding a query language rather than a route. A link to an ad-hoc
          # filter survives as a link to the source, which is the same thing that
          # happens to any URL we don't recognize.
          #
          # An absolute URL qualifies when its host is one the caller allowlisted (the
          # source's base URL and any former domains); the host match is
          # scheme-insensitive, so `http://`, `https://` and protocol-relative `//host`
          # all count. Each host carries a path prefix: a subdirectory install lives
          # under `/forum`, so only a path inside that prefix belongs to the forum (the
          # host may run other apps beside it), while a root-install host (nil prefix)
          # owns every path. A relative URL (a path, no host) qualifies only where it
          # is actually a link: in link syntax `[text](/t/5)`, or as a bare URL
          # detected at a `](…)` link target; a subfolder site writes its relative
          # links with the prefix (`/forum/t/5`), stripped via `base_prefix`. A
          # relative URL bare in prose is left alone, because it stays plain text when
          # the post is cooked, so rewriting it would turn text into a link. A bare
          # URL with no scheme at all (`forum.example.com/t/5`), which core's linkify
          # also links, is never detected here: it contains no character a construct
          # can trigger on.
          # The engine tier rewrites that form in place once the parse confirms it
          # (see {EngineScanner}).
          #
          # An absolute internal URL whose path parses no known route — a real site
          # page (`/faq`, `/search?q=…`) — is still recorded, as a `:site` target:
          # only its origin is rewritten to the destination, and the
          # path/query/fragment ride along in the suffix. That holds in either syntax,
          # bare or bracketed, and down to a URL with no path at all: `https://host`
          # is the forum's front page and `https://host?ref=x` the same with a query,
          # both of which point at a site being retired unless their origin is
          # rewritten. A relative route-less URL stays literal: it is domain-free and
          # already correct on the destination. An unparsed path that OPENS a
          # coordinate route (`/t//209`, `/u/bob!!!`) is neither: its tail
          # plausibly carries the old site's ids, so an origin-only rewrite would
          # carry them onto the new host — no node, and the engine tier reports
          # the construct instead (see `RouteParser.coordinate_shaped?`).
          #
          # The full original URL is kept (`url`) as the importer's fallback; the
          # route reveals the target, and everything after the route (further path,
          # query string, fragment) becomes the suffix, reattached verbatim at render.
          # For a `:site` target the suffix is the whole path (after the prefix).
          class InternalLink < Base
            TRIGGERS = ["[", "h", "H", "/"].freeze

            # The route segments this construct understands, shared by the presence
            # gate and the bare-URL pattern.
            ROUTE_SEGMENT = "t|p|u|users|c|category|g|groups?|tags?|badges"
            private_constant :ROUTE_SEGMENT

            # A relative link (`/t/5`) contains no character of the gate's
            # built-in presence check, so route segments contribute their own
            # (see {Detection#presence_pattern}).
            ROUTE_PRESENCE = %r{/(?:#{ROUTE_SEGMENT})/}
            private_constant :ROUTE_PRESENCE

            # A URL-body character (see `Base::URL_TERMINATORS`). The trailing `\w` on
            # the bare form keeps a sentence's `.`/`,` after the URL out of the match
            # (mirrors `UploadUrl`).
            URL_BODY = /[^#{Base::URL_TERMINATORS}]/
            private_constant :URL_BODY

            # The text takes one level of balanced brackets but no nested link or
            # image (see `Base::LINK_TEXT`), so a citation-style `[see [1]](/t/5)`
            # is rewritten while the `[` of a nested image `[![…](…)](…)` never
            # starts a match at the outer bracket.
            #
            # The destination takes the padding, optional title and `<…>` form
            # CommonMark allows (see `Base::LINK_TAIL`). Without those an internal
            # link written with a title was left alone and kept pointing at the
            # source site. The `<…>` alternative repeats the `url` group name, which
            # Ruby allows: whichever branch matches is the one `match[:url]` reads.
            LINK =
              /\G\[(?<text>#{Base::LINK_TEXT})\]\(#{Base::LINK_GAP}(?:<(?<url>[^<>\n]{1,2048})>|(?<url>#{URL_BODY}{1,2048}))#{Base::LINK_TAIL}/
            private_constant :LINK

            # The bare form fires at every whitespace-preceded `h` and `/` the scanner
            # walks past, so it must reject ordinary words inside the regex engine. A
            # permissive capture-everything pattern here (with the rejection left to
            # `UrlOrigin`/`RouteParser`) costs a MatchData and a string per h-word of
            # every scanned post, which is measurable across a whole conversion. Each
            # branch below therefore starts with something an ordinary word fails on.
            #
            # An absolute URL needs no route segment: the `//` already rejects a plain
            # word, and every path on a configured host belongs to the forum, so a
            # route-less one (`/faq`, `/search?q=…`) becomes a `:site` link exactly
            # like the same URL in link syntax. Whatever follows the host is the path,
            # which also covers a subfolder install (`//host/forum/t/5`) — the prefix
            # comes off with the host's own (see `UrlOrigin.classify`).
            #
            # The scheme is case-insensitive because linkify-it reads it that way, so
            # core links `HTTPS://…` too. The insensitivity stops at the scheme: route
            # segments stay literal, since Rails routing is case-sensitive and `/T/5`
            # is not a topic on the destination either.
            #
            # There need be no path at all: `https://host` is the forum's front page
            # and `https://host?ref=x` the same with a query, and both point at the
            # site being retired unless their origin is rewritten. So the host and
            # everything after it are one run, ending on a word character — which
            # keeps a sentence's `.` outside the URL — or on a `/`, for the root path.
            ABSOLUTE = %r{(?:(?i:https?:)?//#{URL_BODY}{0,2048}[\w/])}
            private_constant :ABSOLUTE

            # A relative URL has no host to reject on, and detection is tried at every
            # `/` in prose (`and/or`, `50/50`), so here a route segment is what tells a
            # link apart from a slash. The lazy `(?:/…)*?` admits a subfolder install's
            # leading segments before it, and demands a real route segment after, so a
            # plain `/` still fails without the group ever expanding.
            RELATIVE =
              %r{(?:/[^/#{Base::URL_TERMINATORS}]{1,255}){0,16}?/(?:#{ROUTE_SEGMENT})/#{URL_BODY}{0,2048}\w}
            private_constant :RELATIVE

            BARE = /\G(?<url>#{ABSOLUTE}|#{RELATIVE})/
            private_constant :BARE

            # @param hosts [Hash{String => (String, nil)}] the source's own hosts (base
            #   URL plus former domains), each downcased and mapped to its path prefix
            #   (`"/forum"` for a subfolder install, `nil` for a root install). An
            #   absolute URL is internal only when its host is a key here; on a prefixed
            #   host only paths inside the prefix qualify. Empty means relative-only.
            # @param base_prefix [String, nil] the current site's own path prefix, used
            #   to strip a subfolder install's prefix from a relative link
            #   (`/forum/t/5`) before the route is parsed. Nil for a root install.
            # @param on_foreign_host [#call, nil] called with the host (a String)
            #   when an absolute URL is rejected for a foreign host but its path
            #   still parses as an internal route — the "did the operator forget a
            #   former domain?" signal. Each host is reported once per
            #   {InternalLink} instance, and the foreign path is parsed as-is: a forgotten domain
            #   that served the forum under a subdirectory parses no route and
            #   stays unreported. Nil skips the extra route parse of a foreign
            #   host, so a run that doesn't want the signal pays nothing beyond the
            #   cheap host rejection.
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
              when 0x5b # `[`
                detect_link(input, pos)
              when 0x68, 0x48, 0x2f
                # 0x68 = `h`, 0x48 = `H`, 0x2f = `/`
                detect_bare(input, pos)
              end
            end

            # For the engine tier, which filters URL values before any construct
            # runs and so never reaches `build` for a foreign link: the same
            # once-per-host signal for an absolute URL whose host isn't
            # configured.
            def note_foreign_url(url)
              origin = classify(url)
              note_foreign_host(origin.host, origin.rest) if origin&.foreign
            end

            # A reference for a URL whose position the engine tier already
            # confirmed but whose surrounding bytes are the URL itself (a bare
            # schemeless domain linkify links, a reference definition's
            # destination). `route_url` is the engine's href and only resolves
            # the host and its prefix — it is a normalized spelling
            # (percent-encoding, an added scheme), and a normalized spelling
            # must never be written back into a post. The route and the stored
            # suffix are read from `url`, the raw spelling at the occurrence,
            # which is also stored as the fallback and the whole construct (so
            # its destination span is the entire snippet). A raw path the route
            # parser cannot read builds no typed target; the coordinate-shape
            # rule then decides between a `:site` rewrite and no node, as
            # everywhere else. The value was tracked before this is called, so
            # no foreign-host signal fires here.
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

            # A route-less absolute URL (`https://host/faq`) carries none of the
            # gate's built-in signals and no route segment, so without an
            # alternative here a post holding nothing else would classify `:none`
            # and keep pointing at the old origin. The hosts themselves do the
            # gating: they are the only ones an absolute URL can be internal on,
            # which is far more selective than `//` and every URL in every post.
            # Matched
            # case-insensitively, since a host may be written in any case.
            # Each host gets its own case-insensitive alternative. Wrapping a
            # `Regexp.union` of them in one `/i` does not work: union serializes what
            # it is given as `(?-mix:…)`, which turns the flag back off inside its own
            # scope, so the hosts end up case-sensitive and an upper-cased one never
            # passes the gate.
            def build_presence_pattern
              return ROUTE_PRESENCE if @hosts.empty?

              Regexp.union(ROUTE_PRESENCE, *@hosts.keys.map { |host| /#{Regexp.escape(host)}/i })
            end

            # A markdown link, unless it's the `[` of an image `![…](…)`, whose `[`
            # sits right after the `!`.
            def detect_link(input, pos)
              return nil if bang_before?(input, pos)

              match = match_at(LINK, input, pos)
              return nil unless match

              build(pos, match, url: match[:url], text: match[:text])
            end

            # The destination's byte offset within the matched construct, and —
            # when the label spells the destination too (a self-link written as
            # `[url](url)`) — that spelling's offset. The importer rewrites
            # exactly these spans inside the verbatim source, so a URL the
            # author repeated in a link title stays the author's text. An
            # ambiguous label (the destination appearing twice) records no
            # label span: better to leave a label untouched than guess.
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

              # On a prefixed host only paths inside the prefix belong to the forum;
              # a sibling app's path (or a relative link that isn't the subfolder
              # site's own) stays literal — no route, no `:site` rewrite, no signal.
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

            # The path/query/fragment part of the raw spelling. A schemeful or
            # protocol-relative raw URL splits like any other; a bare
            # schemeless domain starts with its host, so the part from the
            # first `/`, `?` or `#` on is the path (a bare domain with no path
            # is the site's front page: an empty rest).
            def raw_rest(url)
              host, rest = UrlOrigin.split(url)
              return rest unless host.nil? && rest.nil?

              start = url.index(%r{[/?\#]})
              start.nil? ? "" : url[start..]
            end

            # A resolved route builds a typed target; an absolute internal URL with no
            # route builds a `:site` target (origin-only rewrite). A relative route-less
            # URL is domain-free and already correct on the destination, so it stays
            # literal (nil node) — and so does a coordinate-shaped path that failed to
            # parse: swapping its origin would carry the old site's ids onto the new
            # host, which is worse than the stale-but-honest verbatim link the engine
            # tier reports.
            def route_or_site_node(url:, text:, path:, host:, url_offset:, label_url_offset:)
              if (target = RouteParser.parse(path))
                # `path` is the extracted URL's own string (character domain), so the
                # suffix is a plain character slice — only the input-domain positions
                # in the `Match` are byte offsets.
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

            # A foreign host is rejected before routing (the cheap check). Only when
            # a caller asked for the signal do we route-parse it, to tell an
            # internal-looking self-link on an unconfigured host from an ordinary
            # external link, and report the former — once per host: a forgotten
            # former domain can appear in millions of posts, and the signal's
            # value is the host name, not its frequency.
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
