# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class Converter < Conversion::Base
        # Steps run concurrently and a Postgres connection can't be shared, so each
        # step gets its own adapter; the step's source closes it in its `cleanup`.
        def step_args(step_class)
          source_db = Adapter::Postgres.new(settings[:source_db])

          # Only the Posts step classifies `@group`/`@here` mentions, so only it
          # pays for the two metadata queries. They reuse the step's own adapter and
          # hand back plain values, so no connection is shared across the steps.
          return { source_db: } unless step_class == Posts

          { source_db:, group_names: group_names(source_db), here_mention: here_mention(source_db) }
        end

        private

        # Lowercased source group names, so the Posts step can classify `@group`
        # mentions.
        def group_names(source_db)
          source_db.query("SELECT LOWER(name) AS name FROM groups").map { |row| row[:name] }
        end

        # The source's `here_mention` setting value (the configurable name that
        # triggers an `@here` mention); falls back to the Discourse default, which
        # isn't stored in `site_settings`.
        def here_mention(source_db)
          source_db.query_value("SELECT value FROM site_settings WHERE name = 'here_mention'") ||
            "here"
        end
      end
    end
  end
end
