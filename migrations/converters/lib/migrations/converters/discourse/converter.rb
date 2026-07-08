# frozen_string_literal: true

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
          }
        end

        private

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
        # Usernames can reach seven figures, so they're streamed straight into the
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

          Migrations::SortedStringSet.new(names)
        end

        # The names a hashtag can address on the source — every category slug, every
        # `parent:child` category path, and every tag name (synonyms are tags too, so
        # `SELECT name FROM tags` already covers them). Normalized like the importer
        # normalizes them when it resolves a hashtag, so the Posts step defers only a
        # `#name` that names something real and the two sides agree on what matches.
        def hashtag_names(source_db)
          names = Set.new

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

          names
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
