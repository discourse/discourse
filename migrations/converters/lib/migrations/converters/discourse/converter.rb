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

          {
            source_db:,
            group_names: group_names(source_db),
            here_mention: here_mention(source_db),
            hashtag_names: hashtag_names(source_db),
            custom_emoji_names: custom_emoji_names(source_db),
          }
        end

        private

        # Source group names, so the Posts step can classify `@group` mentions.
        def group_names(source_db)
          source_db.query("SELECT name FROM groups").map { |row| row[:name] }
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
