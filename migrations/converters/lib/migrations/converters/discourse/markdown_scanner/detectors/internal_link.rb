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
          # is actually a link: in link syntax `[text](/t/5)`, or as a bare URL the
          # walk reaches at a `](…)` link target; a subfolder site writes its relative
          # links with the prefix (`/forum/t/5`), stripped via `base_prefix`. A
          # relative URL bare in prose is left alone, because it stays plain text when
          # the post is cooked, so rewriting it would turn text into a link. A bare
          # URL with no scheme at all (`forum.example.com/t/5`), which core's linkify
          # also links, is never detected: the walk has nothing to trigger on there
          # (see LIMITATIONS.md).
          #
          # An absolute internal URL whose path parses no known route — a real site
          # page (`/faq`, `/search?q=…`) or junk (`/t/slug/5a`) — is still recorded, as
          # a `:site` target: only its origin is rewritten to the destination, and the
          # path/query/fragment ride along in the suffix. That holds in either syntax,
          # bare or bracketed, and down to a URL with no path at all: `https://host`
          # is the forum's front page and `https://host?ref=x` the same with a query,
          # both of which point at a site being retired unless their origin is
          # rewritten. A relative route-less URL stays literal: it is domain-free and
          # already correct on the destination.
          #
          # The full original URL is kept (`url`) as the importer's fallback; the
          # route reveals the target, and everything after the route (further path,
          # query string, fragment) becomes the suffix, reattached verbatim at render.
          # For a `:site` target the suffix is the whole path (after the prefix).
          class InternalLink < Base
            TRIGGERS = ["[", "h", "H", "/"].freeze

            # The route segments this detector understands, shared by the presence
            # gate and the bare-URL pattern.
            ROUTE_SEGMENT = "t|p|u|users|c|g|tags?|badges"
            private_constant :ROUTE_SEGMENT

            # A relative link (`/t/5`) contains no character of the scanner's
            # built-in skip check, so route segments contribute their own (see
            # {Base#presence_pattern}).
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
            # `split_host`/`RouteParser`) costs a MatchData and a string per h-word of
            # every scanned post, which is measurable across a whole conversion. Each
            # branch below therefore starts with something an ordinary word fails on.
            #
            # An absolute URL needs no route segment: the `//` already rejects a plain
            # word, and every path on a configured host belongs to the forum, so a
            # route-less one (`/faq`, `/search?q=…`) becomes a `:site` link exactly
            # like the same URL in link syntax. Whatever follows the host is the path,
            # which also covers a subfolder install (`//host/forum/t/5`) — the prefix
            # comes off in `strip_prefix`.
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

            # A relative URL has no host to reject on, and the walk stops at every `/`
            # in prose (`and/or`, `50/50`), so here a route segment is what tells a
            # link apart from a slash. The lazy `(?:/…)*?` admits a subfolder install's
            # leading segments before it, and demands a real route segment after, so a
            # plain `/` still fails without the group ever expanding.
            RELATIVE =
              %r{(?:/[^/#{Base::URL_TERMINATORS}]{1,255}){0,16}?/(?:#{ROUTE_SEGMENT})/#{URL_BODY}{0,2048}\w}
            private_constant :RELATIVE

            BARE = /\G(?<url>#{ABSOLUTE}|#{RELATIVE})/
            private_constant :BARE

            # Splits a URL into its host (nil when relative) and the rest — the path,
            # query and fragment, starting at whichever of `/`, `?` or `#` comes
            # first. A protocol-relative `//host` and an explicit `http(s)://host`
            # both yield the host; a leading `/` (but not `//`) is relative. The host
            # stops at `?` and `#` so `https://host?ref=x` is the site root with a
            # query, not a host with a `?` in its name. Anything the pattern can't
            # take whole (`mailto:…`, a bare word) isn't an internal link.
            SPLIT = %r{\A(?:(?i:https?:)?//(?<host>[^/?\#]+))?(?<rest>[/?\#]\S*)?\z}
            private_constant :SPLIT

            # A real segment boundary right after a host prefix: the remainder begins a
            # new path segment (`/`), the query (`?`) or the fragment (`#`). This keeps
            # `/forum` from matching inside `/forumxyz`.
            PREFIX_BOUNDARY = %r{\A[/?#]}
            private_constant :PREFIX_BOUNDARY

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
            #   former domain?" signal. Nil skips the extra route parse of a foreign
            #   host, so a run that doesn't want the signal pays nothing beyond the
            #   cheap host rejection.
            def initialize(hosts: {}, base_prefix: nil, on_foreign_host: nil)
              @hosts = hosts
              @base_prefix = base_prefix
              @reported_foreign_hosts = Set.new
              @on_foreign_host = on_foreign_host
              @presence_pattern = build_presence_pattern
            end

            def presence_pattern
              @presence_pattern
            end

            def detect(input, pos, byte)
              case byte
              when 0x5b # `[`
                detect_link(input, pos)
              when 0x68, 0x48, 0x2f
                # 0x68 = `h`, 0x48 = `H`, 0x2f = `/`
                detect_bare(input, pos)
              end
            end

            private

            # A route-less absolute URL (`https://host/faq`) carries none of the
            # scanner's built-in signals and no route segment, so without an
            # alternative here a post holding nothing else would skip the walk and
            # keep pointing at the old origin. The hosts themselves are the gate: they
            # are the only ones an absolute URL can be internal on, which is far more
            # selective than gating on `//` and every URL in every post. Matched
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

              # Link syntax: the URL is a link, so a relative one is fine here.
              build(pos, match, url: match[:url], text: match[:text], allow_relative: true)
            end

            # A bare URL starts at a bare-URL boundary (line start, whitespace, or the
            # right kind of `(…)`; see {Boundaries#bare_url_boundary_before?}). A normal
            # `[text](url)` is consumed whole at its `[` trigger, so the walk reaches an
            # inner URL only when the outer bracket wasn't a handled link — a nested
            # image `[![…](…)](url)` whose outer target we do want, versus an image's
            # own `![alt](url)` src or a foreign link's target, which the paren check
            # deliberately leaves alone.
            #
            # A bare relative URL is a link only at a `](…)` target; in prose it stays
            # plain text once cooked, so there we leave it literal (only an absolute
            # bare URL is rewritten in prose). `split_host` reports the relative case
            # inside `build`, so the boundary form we admit at is passed down.
            def detect_bare(input, pos)
              return nil unless bare_url_boundary_before?(input, pos)

              match = match_at(BARE, input, pos)
              return nil unless match
              return nil if inadmissible_protocol_relative?(input, pos, match[:url])

              build(
                pos,
                match,
                url: match[:url],
                text: nil,
                allow_relative: link_target_boundary_before?(input, pos),
              )
            end

            def build(pos, match, url:, text:, allow_relative:)
              host, rest = split_host(url)
              return nil unless rest
              return nil if host.nil? && !allow_relative

              if host
                unless @hosts.key?(host)
                  note_foreign_host(host, rest)
                  return nil
                end
                prefix = @hosts[host]
              else
                prefix = @base_prefix
              end

              # On a prefixed host only paths inside the prefix belong to the forum;
              # a sibling app's path (or a relative link that isn't the subfolder
              # site's own) stays literal — no route, no `:site` rewrite, no signal.
              path = strip_prefix(rest, prefix)
              return nil if path.nil?

              node = route_or_site_node(url:, text:, path:, host:)
              return nil unless node

              Match.new(start_pos: pos, end_pos: match.byteoffset(0).last, node:)
            end

            # A resolved route builds a typed target; an absolute internal URL with no
            # route builds a `:site` target (origin-only rewrite). A relative route-less
            # URL is domain-free and already correct on the destination, so it stays
            # literal (nil node).
            def route_or_site_node(url:, text:, path:, host:)
              if (target = RouteParser.parse(path))
                # `path` is the extracted URL's own string (character domain), so the
                # suffix is a plain character slice — only the input-domain positions
                # in the `Match` are byte offsets.
                target_reference(url:, text:, target:, suffix: path[target[:route_length]..])
              elsif host
                site_reference(url:, text:, suffix: path)
              end
            end

            def target_reference(url:, text:, target:, suffix:)
              InternalLinkReference.new(
                url:,
                text:,
                target_type: target[:target_type],
                target_id: target[:target_id],
                target_name: target[:target_name],
                target_topic_id: target[:target_topic_id],
                target_post_number: target[:target_post_number],
                target_suffix: suffix.presence,
              )
            end

            def site_reference(url:, text:, suffix:)
              InternalLinkReference.new(
                url:,
                text:,
                target_type: :site,
                target_id: nil,
                target_name: nil,
                target_topic_id: nil,
                target_post_number: nil,
                target_suffix: suffix.presence,
              )
            end

            # The path remainder after the host's prefix, or nil when the URL falls
            # outside the prefix (it belongs to another app on the same host). A nil
            # prefix (root install) owns every path, so the whole path is returned. The
            # prefix must end on a real segment boundary — `/forum/t/…` and `/forum`
            # itself match, `/forumxyz` does not.
            def strip_prefix(rest, prefix)
              return rest if prefix.nil?
              return "" if rest == prefix
              return nil unless rest.start_with?(prefix)

              remainder = rest[prefix.length..]
              PREFIX_BOUNDARY.match?(remainder) ? remainder : nil
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

            # @return [Array(String, String), nil] `[host, rest]` for an internal URL
            #   shape, else nil. `host` is nil for a relative URL. Only a default
            #   port is dropped: `example.com:8443` can be a different application
            #   than `example.com`, so a non-default port stays part of the host
            #   identity and must appear in the configured host set to match.
            def split_host(url)
              match = SPLIT.match(url)
              return nil unless match

              host = match[:host]&.sub(/:(?:80|443)\z/, "")&.downcase
              rest = match[:rest]
              # A host with no path at all is the site's front page, and its origin
              # needs rewriting like any other. Without a host there is nothing to
              # rewrite, so a URL that is neither stays literal.
              return nil if host.nil? && rest.nil?

              [host, rest || ""]
            end
          end
        end
      end
    end
  end
end
