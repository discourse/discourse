# frozen_string_literal: true

require "uri"

module Migrations
  module Converters
    module Discourse
      class Converter < Conversion::Base
        # Steps run concurrently and a Postgres connection can't be shared, so each
        # step gets its own adapter; the step's source closes it in its `cleanup`.
        def step_args(step_class)
          source_db = Adapter::Postgres.new(settings[:source_db])

          # Only the Posts step classifies `@group`/`@here` mentions and extracts
          # custom emoji, so only it pays for these metadata queries. They reuse the
          # step's own adapter and hand back plain values, so no connection is shared
          # across the steps.
          return { source_db: } unless step_class == Posts

          # Loaded once and reused: `mention_names` folds the group names and the
          # `here_mention` value into its gate, so re-querying them would be waste.
          group_names = group_names(source_db)
          here_mention = here_mention(source_db)

          {
            source_db:,
            group_names:,
            here_mention:,
            mention_names: mention_names(source_db, group_names, here_mention),
            hashtag_names: hashtag_names(source_db),
            custom_emoji_names: custom_emoji_names(source_db),
            internal_link_hosts:,
            internal_link_base_prefix:,
          }
        end

        private

        # The source's own hosts mapped to their path prefixes, so the Posts step can
        # tell an absolute internal link from an external one and, on a host shared
        # with other apps, which paths belong to the forum. Built from `base_url` and
        # any `former_domains` under the `source_site` setting (a site that moved
        # carries links to both). Each host is downcased with the port dropped, so
        # `http://`, `https://` and protocol-relative links all match; the prefix is
        # the URL's path (`/forum` for a subfolder install, nil for a root install).
        # Entries may carry different prefixes when a former root domain later moved
        # into a subfolder. No setting means an empty hash, i.e. relative-only
        # detection.
        def internal_link_hosts
          source_site_urls.to_h { |url| host_and_prefix(url) }
        end

        # The current site's own path prefix, taken from `base_url`, so the Posts step
        # can strip it from a relative internal link (`/forum/t/5`) before parsing the
        # route. Nil for a root install (or no `base_url`).
        def internal_link_base_prefix
          base_url = settings.dig(:source_site, :base_url)
          base_url && host_and_prefix(base_url).last
        end

        def source_site_urls
          site = settings[:source_site] || {}
          [site[:base_url], *Array(site[:former_domains])].compact
        end

        # Splits a configured URL into its downcased host (port dropped) and path
        # prefix, tolerating a bare host, a scheme-less `//host`, and a full URL with a
        # path. The prefix is normalized to a leading slash and no trailing slash, or
        # nil when the path is empty or the bare root `/`. A malformed URL or a URL
        # with no host raises, so a settings typo surfaces here instead of silently
        # disabling link detection.
        def host_and_prefix(url)
          normalized = url.to_s.strip
          normalized = "//#{normalized}" if normalized.exclude?("//")
          uri = URI.parse(normalized)
          host = uri.host&.downcase

          raise "Invalid source_site URL (no host): #{url.inspect}" if host.nil? || host.empty?

          [host, normalize_prefix(uri.path)]
        rescue URI::InvalidURIError => e
          raise "Invalid source_site URL #{url.inspect}: #{e.message}"
        end

        def normalize_prefix(path)
          prefix = path.to_s.chomp("/")
          prefix.empty? ? nil : prefix
        end

        # Source group names, so the Posts step can classify `@group` mentions.
        def group_names(source_db)
          source_db.query("SELECT name FROM groups").map { |row| row[:name] }
        end

        # Every name that can legitimately follow `@`, so the Posts step defers only
        # a mention that names something real and leaves the rest (`@3pm`) as plain
        # text: every username, every group name, the source's `here_mention` value
        # and the literal `all`. Without the last three, `@staff`, `@here` and `@all`
        # would be dropped — the gate must never be usernames only. Normalized like
        # the importer normalizes a mention when it resolves it, so the two sides
        # agree on what matches.
        #
        # Usernames can run into the millions, so they're streamed straight into the
        # gate; the query is drained fully (every row consumed) so the connection is
        # clean for the queries that follow.
        def mention_names(source_db, group_names, here_mention)
          names = []

          source_db
            .query("SELECT username FROM users")
            .each { |row| names << normalize(row[:username]) }

          group_names.each { |name| names << normalize(name) }
          # `here_mention` only falls back to "here" for a NULL setting, so a blank
          # value would slip an empty name into the gate.
          names << normalize(here_mention) if here_mention.present?
          names << normalize("all")

          Migrations::SortedStringSet.new(names)
        end

        # The names a hashtag can address on the source — every category slug, every
        # `parent:child` category path, and every tag name (synonyms are tags too, so
        # `SELECT name FROM tags` already covers them). Normalized like the importer
        # normalizes them when it resolves a hashtag, so the Posts step defers only a
        # `#name` that names something real and the two sides agree on what matches.
        def hashtag_names(source_db)
          names = []

          source_db
            .query(<<~SQL)
              SELECT c.slug AS slug, parent.slug AS parent_slug
              FROM categories c
                   LEFT JOIN categories parent ON parent.id = c.parent_category_id
            SQL
            .each do |row|
              names << normalize(row[:slug])
              names << normalize("#{row[:parent_slug]}:#{row[:slug]}") if row[:parent_slug]
            end

          source_db.query("SELECT name FROM tags").each { |row| names << normalize(row[:name]) }

          # Tags reach six figures on big sites, so the gate is a SortedStringSet for
          # the same copy-on-write reason the mention gate is (and it dedupes here).
          Migrations::SortedStringSet.new(names)
        end

        # Source custom emoji names, so the Posts step extracts only `:name:`
        # shortcodes that name a real custom emoji (standard ones stay plain text).
        def custom_emoji_names(source_db)
          source_db.query("SELECT name FROM custom_emojis").map { |row| row[:name] }
        end

        # The source's `here_mention` setting value (the configurable name that
        # triggers an `@here` mention); falls back to the Discourse default, which
        # isn't stored in `site_settings`.
        def here_mention(source_db)
          source_db.query_value("SELECT value FROM site_settings WHERE name = 'here_mention'") ||
            "here"
        end

        def normalize(name)
          Migrations::NameNormalizer.normalize(name)
        end
      end
    end
  end
end
