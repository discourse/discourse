# frozen_string_literal: true

require "uri"

module Migrations
  module Converters
    module Discourse
      class Converter < Conversion::Base
        include Reporting::Formatting

        # Groups the foreign-host link entries the Posts step logged (see
        # `Posts::FOREIGN_LINK_LOG_MESSAGE`) by host, most-seen first.
        FOREIGN_LINK_SUMMARY_SQL = <<~SQL
          SELECT json_extract(details, '$.host') AS host, COUNT(*) AS count
          FROM log_entries
          WHERE type = ? AND message = ?
          GROUP BY host
          ORDER BY count DESC, host
        SQL
        private_constant :FOREIGN_LINK_SUMMARY_SQL

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
          }
        end

        # End-of-run hook (see `Conversion::Base#run`): surfaces the internal-looking
        # links that pointed at hosts the source_site settings don't cover, so the
        # operator can spot a former domain they forgot to configure.
        # @param connection [Database::Connection] the run DB, log entries merged in
        # @param reporter [Reporting::Reporter] prints the notice under the summary
        def report_diagnostics(connection, reporter)
          notice = foreign_link_notice(connection)
          reporter.report_summary_notice(notice) if notice
        end

        private

        # The per-host tally as one summary line, or nil when nothing pointed at an
        # unconfigured host. Counted even when no source_site is set (every absolute
        # route-shaped link is "foreign" then), so the hint also nudges an operator
        # who never configured `base_url` at all — hence the neutral wording.
        def foreign_link_notice(connection)
          rows =
            connection.query(
              FOREIGN_LINK_SUMMARY_SQL,
              Database::IntermediateDB::LogEntry::INFO,
              Posts::FOREIGN_LINK_LOG_MESSAGE,
            )
          return nil if rows.empty?

          total = rows.sum { |row| row[:count] }
          hosts = rows.map { |row| "#{row[:host]} (#{format_count(row[:count])})" }.join(", ")

          "⚠ " +
            I18n.t(
              "converter.foreign_internal_links",
              count: total,
              number: format_count(total),
              hosts:,
            )
        end

        # The source's own hosts, so the Posts step can tell an absolute internal link
        # from an external one. Built from the `base_url` and any `former_domains`
        # under the `source_site` setting (a site that moved carries links to both).
        # Only the host is kept (scheme and port dropped), so `http://`, `https://`
        # and protocol-relative links all match. No setting means an empty set, i.e.
        # relative-only link detection.
        def internal_link_hosts
          site = settings[:source_site] || {}
          urls = [site[:base_url], *Array(site[:former_domains])].compact

          Set.new(urls.filter_map { |url| host_of(url) })
        end

        # Extracts the host from a configured base URL, tolerating a bare host, a
        # scheme-less `//host`, a full URL, and a trailing path or port.
        def host_of(url)
          url = url.to_s.strip
          return nil if url.empty?

          url = "//#{url}" if url.exclude?("//")
          URI.parse(url).host&.downcase
        rescue URI::InvalidURIError
          nil
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
