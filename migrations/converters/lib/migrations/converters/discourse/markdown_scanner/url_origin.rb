# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # The one URL-origin reading shared by everything that must agree on
        # what "the source's own URL" means: the {Constructs::InternalLink}
        # grammar, the {EngineScanner}'s tracked-value filter, and the
        # foreign-host signal. With one shared reading, the host, port and
        # prefix rules cannot drift apart between those places.
        module UrlOrigin
          # Splits into scheme, `//host` and the rest (path/query/fragment,
          # starting at whichever of `/`, `?` or `#` comes first). The host
          # stops at `?`/`#` so `https://host?ref=x` is the site root with a
          # query, not a host with a `?` in its name. Anything the pattern
          # can't take whole (`mailto:…`, a bare word) isn't an internal URL.
          SPLIT = %r{\A(?:(?:(?<scheme>(?i:https?)):)?//(?<host>[^/?\#]+))?(?<rest>[/?\#]\S*)?\z}
          private_constant :SPLIT

          # A real segment boundary right after a path prefix: the remainder
          # begins a new segment (`/`), the query (`?`) or the fragment (`#`).
          # This keeps `/forum` from matching inside `/forumxyz`.
          PREFIX_BOUNDARY = %r{\A[/?#]}
          private_constant :PREFIX_BOUNDARY

          # @return [Array(String, String), nil] `[host, rest]` for an
          #   internal-URL shape, else nil. `host` is nil for a relative URL.
          #   Only a scheme's OWN default port is dropped (`:80` for http,
          #   `:443` for https): `https://host:80` is a non-default origin, and
          #   a protocol-relative `//host:8443` has no scheme to default from —
          #   both keep their port as part of the host identity and match only
          #   a configured host spelled with it.
          def self.split(url)
            match = SPLIT.match(url)
            return nil unless match

            host = match[:host]&.downcase
            if host
              case match[:scheme]&.downcase
              when "http"
                host = host.delete_suffix(":80")
              when "https"
                host = host.delete_suffix(":443")
              end
            end

            rest = match[:rest]
            # A host with no path at all is the site's front page, and its
            # origin needs rewriting like any other. Without a host there is
            # nothing to rewrite, so a URL that is neither stays literal.
            return nil if host.nil? && rest.nil?

            [host, rest || ""]
          end

          # Where a URL sits relative to the source's own hosts and prefixes.
          # `host` is nil for a relative URL. `path` is the remainder inside
          # the owning prefix when the URL is the source's own, else nil.
          # `prefix` is the prefix `path` was measured against, so a caller
          # that resolves the host from one spelling of a URL can measure a
          # second spelling against the same prefix. `foreign` marks an
          # absolute URL whose host is not configured — the signal a
          # conversion may want to hear about once per host.
          Origin = Data.define(:host, :rest, :path, :prefix, :foreign)

          # The one place that combines {.split} and {.path_within_prefix}
          # with the configured hosts, so a construct grammar and the
          # engine tier's value filter read a URL identically. Returns nil
          # for anything that is not an internal-URL shape at all.
          #
          # @param hosts [Hash{String => (String, nil)}] host => path prefix
          # @param base_prefix [String, nil] the prefix for relative URLs
          # @return [Origin, nil]
          def self.classify(url, hosts:, base_prefix:)
            host, rest = split(url)
            return nil if rest.nil?

            if host
              unless hosts.key?(host)
                return Origin.new(host:, rest:, path: nil, prefix: nil, foreign: true)
              end

              prefix = hosts[host]
            else
              prefix = base_prefix
            end

            Origin.new(
              host:,
              rest:,
              path: path_within_prefix(rest, prefix),
              prefix:,
              foreign: false,
            )
          end

          # The path remainder after `prefix`, or nil when the URL falls
          # outside it (it belongs to another app beside the forum). A nil
          # prefix (root install) owns every path. The prefix must end on a
          # real segment boundary — `/forum/t/…` and `/forum` itself match,
          # `/forumxyz` does not.
          def self.path_within_prefix(rest, prefix)
            return rest if prefix.nil?
            return "" if rest == prefix
            return nil unless rest.start_with?(prefix)

            remainder = rest[prefix.length..]
            PREFIX_BOUNDARY.match?(remainder) ? remainder : nil
          end
        end
      end
    end
  end
end
