# frozen_string_literal: true

require "uri"

module Migrations
  module Converters
    module Discourse
      class Converter < Conversion::Base
        POSTS_ARGS_LOCK = Mutex.new
        private_constant :POSTS_ARGS_LOCK

        # Steps run concurrently and a Postgres connection can't be shared, so each
        # step gets its own adapter; the step's source closes it in its `cleanup`.
        def step_args(step_class)
          source_db = Adapter::Postgres.new(settings[:source_db])
          return { source_db: } unless step_class == Posts

          { source_db:, **posts_args }
        end

        private

        # Everything the Posts step needs besides its own connection: the name
        # gates, the engine bundle and config, the source site's hosts. Loaded
        # once per run. `step_args` is called from two scheduler threads and
        # again in every worker, so without the memo each of them would stream
        # all usernames again.
        def posts_args
          POSTS_ARGS_LOCK.synchronize { @posts_args ||= load_posts_args }
        end

        # Uses its own connection and closes it right away, so the workers
        # don't inherit an idle one.
        def load_posts_args
          source_db = Adapter::Postgres.new(settings[:source_db])

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
            group_names:,
            here_mention:,
            mention_names: mention_names(source_db, group_names, here_mention),
            # The engine config builds the hashtag names from the same category
            # and tag lists, so the gate and the engine agree on what a `#name`
            # can be.
            hashtag_names: markdown_config.hashtag_names,
            custom_emoji_names:,
            # Plain data the workers inherit across the fork. The V8 context
            # that runs it is created per worker in the step.
            markdown_bundle: MarkdownEngine::Bundle.load_or_build,
            markdown_config:,
            internal_link_hosts:,
            internal_link_base_prefix:,
          }
        ensure
          source_db&.close
        end

        # The source site's hosts and their path prefixes, from `base_url` and
        # `former_domains` in the `source_site` settings. Hosts are downcased
        # without the port, so `http://`, `https://` and `//host` links all
        # match. The prefix is the URL's path (`/forum` for a subfolder install,
        # nil for a root install) and can differ per host. Without the setting
        # only relative links are detected.
        def internal_link_hosts
          source_site_urls.to_h { |url| host_and_prefix(url) }
        end

        # The path prefix of `base_url`. It is stripped from relative internal
        # links (`/forum/t/5`) before the route is parsed. Nil for a root install.
        def internal_link_base_prefix
          base_url = settings.dig(:source_site, :base_url)
          base_url && host_and_prefix(base_url).last
        end

        def source_site_urls
          site = settings[:source_site] || {}
          [site[:base_url], *Array(site[:former_domains])].compact
        end

        # Splits a URL into its downcased host without the port and its path
        # prefix. Accepts a bare host, `//host` and a full URL. The prefix has a
        # leading slash and no trailing slash, or is nil for an empty path or `/`.
        # A URL without a host raises, so a typo in the settings doesn't silently
        # turn link detection off.
        def host_and_prefix(url)
          normalized = url.to_s.strip
          normalized = "//#{normalized}" if normalized.exclude?("//")
          uri = URI.parse(normalized)
          host = uri.host&.downcase

          raise "Invalid source_site URL (no host): #{url.inspect}" if host.blank?

          [host, normalize_prefix(uri.path)]
        rescue URI::InvalidURIError => e
          raise "Invalid source_site URL #{url.inspect}: #{e.message}"
        end

        def normalize_prefix(path)
          prefix = path.to_s.chomp("/")
          prefix.empty? ? nil : prefix
        end

        # The engine config takes the markdown settings from this,
        # `here_mention` the name of the `@here` mention.
        def source_settings(source_db)
          source_db
            .query("SELECT name, value FROM site_settings")
            .to_h { |row| [row[:name], row[:value]] }
        end

        # Source group names, so the Posts step can classify `@group` mentions.
        def group_names(source_db)
          source_db.query("SELECT name FROM groups").map { |row| row[:name] }
        end

        # Every name that can follow `@`: usernames, group names, the source's
        # `here_mention` value and `all`. Without the last three, `@staff`,
        # `@here` and `@all` would be dropped. Normalized the same way the
        # importer normalizes a mention when it resolves it.
        #
        # There can be millions of usernames, so they are streamed into the set.
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

        # A category is addressed by its slug, a nested one also by `parent:child`.
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

        # Only `:name:` shortcodes of a real custom emoji are extracted; standard
        # emoji stay text.
        def custom_emoji_names(source_db)
          source_db.query("SELECT name FROM custom_emojis").map { |row| row[:name] }
        end

        # The Discourse default isn't stored in `site_settings` until someone
        # changes it.
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
