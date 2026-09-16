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

          # Only the Posts step extracts embeds, so only it pays for the metadata
          # queries below. They reuse the step's own adapter and hand back plain
          # values, so no connection is shared across the steps.
          return { source_db: } unless step_class == Posts

          source_settings = source_settings(source_db)
          group_names = group_names(source_db)
          here_mention = here_mention(source_settings)
          custom_emoji_names = custom_emoji_names(source_db)

          markdown_config =
            MarkdownEngine::Config.new(
              source_settings:,
              category_slugs: category_slugs(source_db),
              tag_names: tag_names(source_db),
              custom_emoji_names:,
            )

          {
            source_db:,
            group_names:,
            here_mention:,
            mention_names: mention_names(source_db, group_names, here_mention),
            # The markdown engine and the extractor both decide whether a `#name`
            # addresses anything, so the gate is the very set the engine config
            # derives from the category and tag lists. Building it here, before the
            # step forks, is also what keeps it shared across the workers.
            hashtag_names: markdown_config.hashtag_names,
            custom_emoji_names:,
            markdown_bundle:,
            markdown_config:,
            internal_link_hosts:,
            internal_link_base_prefix:,
          }
        end

        private

        # The compiled markdown JavaScript, built (or read back from its cache) once
        # for the whole run. It is plain data every worker inherits across the fork;
        # the V8 isolate that runs it is per-worker and is created in the step.
        def markdown_bundle
          @markdown_bundle ||= MarkdownEngine::Bundle.load_or_build
        end

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

        # The source's site settings as a `name => value` hash. It's a small table and
        # both consumers want a different slice of it: the markdown engine takes the
        # settings its pipeline reads, and `here_mention` names what an `@here`
        # mention is spelled as on this source.
        def source_settings(source_db)
          source_db
            .query("SELECT name, value FROM site_settings")
            .to_h { |row| [row[:name], row[:value]] }
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
          names << normalize(here_mention)
          names << normalize("all")

          Migrations::CompactStringSet.new(names)
        end

        # Every way a hashtag can address a source category: by the category's own
        # slug, and for a nested one also by its `parent:child` path.
        def category_slugs(source_db)
          slugs = []

          source_db
            .query(<<~SQL)
              SELECT c.slug AS slug, parent.slug AS parent_slug
              FROM categories c
                   LEFT JOIN categories parent ON parent.id = c.parent_category_id
            SQL
            .each do |row|
              slugs << row[:slug]
              slugs << "#{row[:parent_slug]}:#{row[:slug]}" if row[:parent_slug]
            end

          slugs
        end

        # Synonyms are tags too, so this already covers them.
        def tag_names(source_db)
          source_db.query("SELECT name FROM tags").map { |row| row[:name] }
        end

        # Source custom emoji names, so the Posts step extracts only `:name:`
        # shortcodes that name a real custom emoji (standard ones stay plain text).
        def custom_emoji_names(source_db)
          source_db.query("SELECT name FROM custom_emojis").map { |row| row[:name] }
        end

        # The configurable name that triggers an `@here` mention. It falls back to the
        # Discourse default, which isn't in `site_settings` until someone changes it.
        def here_mention(source_settings)
          source_settings["here_mention"].presence || "here"
        end

        def normalize(name)
          Migrations::NameNormalizer.normalize(name)
        end
      end
    end
  end
end
