# frozen_string_literal: true

module DiscourseAi
  module Translation
    class TagCandidates < BaseCandidates
      def self.progress_summary
        connection = ActiveRecord::Base.connection
        supported_bases =
          SiteSetting
            .content_localization_supported_locales
            .split("|")
            .map { |locale| locale.downcase.tr("-", "_").split("_").first }
            .uniq
        bases_sql =
          "ARRAY[#{supported_bases.map { |base| connection.quote(base) }.join(",")}]::text[]"
        tags_sql = get.select(:id, :locale).to_sql

        sql = <<~SQL
          WITH supported(base) AS MATERIALIZED (
            SELECT unnest(#{bases_sql})
          )
          SELECT
            COUNT(*)::bigint AS total_count,
            COUNT(*) FILTER (
              WHERE tag.locale IS NOT NULL
                AND EXISTS (SELECT 1 FROM supported)
                AND NOT EXISTS (
                  SELECT 1
                  FROM supported target
                  WHERE target.base <> split_part(
                    lower(replace(tag.locale, '-', '_')), '_', 1
                  )
                    AND NOT EXISTS (
                      SELECT 1
                      FROM tag_localizations localization
                      WHERE localization.tag_id = tag.id
                        AND split_part(
                          lower(replace(localization.locale, '-', '_')), '_', 1
                        ) = target.base
                    )
                )
            )::bigint AS translated_count,
            COUNT(*) FILTER (
              WHERE tag.locale IS NULL
            )::bigint AS needs_language_detection_count
          FROM (#{tags_sql}) tag
        SQL

        result = DB.query(sql).first

        {
          target_type: "tag",
          total_count: result.total_count,
          translated_count: result.translated_count,
          needs_language_detection_count: result.needs_language_detection_count,
        }
      end

      def self.progress_details
        supported_locales =
          ActiveRecord::Base.connection.quote(SiteSetting.content_localization_supported_locales)

        sql = <<~SQL
          WITH supported AS MATERIALIZED (
            SELECT DISTINCT ON (
                     split_part(lower(replace(locale, '-', '_')), '_', 1)
                   )
                   locale,
                   split_part(
                     lower(replace(locale, '-', '_')), '_', 1
                   ) AS base
            FROM unnest(string_to_array(#{supported_locales}, '|'))
              WITH ORDINALITY configured(locale, position)
            ORDER BY split_part(
                       lower(replace(locale, '-', '_')), '_', 1
                     ),
                     position
          ),
          tags AS MATERIALIZED (
            SELECT tags.id,
                   tags.locale,
                   split_part(
                     lower(replace(tags.locale, '-', '_')), '_', 1
                   ) AS base
            FROM tags
          ),
          totals AS (
            SELECT COUNT(*)::bigint AS total
            FROM tags
          ),
          source_locale_counts AS (
            SELECT base,
                   COUNT(*)::bigint AS count
            FROM tags
            WHERE locale IS NOT NULL
            GROUP BY base
          ),
          translated_counts AS (
            SELECT supported.base,
                   COUNT(DISTINCT tags.id)::bigint AS count
            FROM tags
            JOIN tag_localizations localization
              ON localization.tag_id = tags.id
            JOIN supported
              ON supported.base = split_part(
                lower(replace(localization.locale, '-', '_')), '_', 1
              )
            WHERE tags.locale IS NOT NULL
              AND tags.base <> supported.base
            GROUP BY supported.base
          )
          SELECT supported.locale,
                 COALESCE(translated.count, 0)::bigint AS translated_count,
                 (
                   totals.total -
                   COALESCE(source_locales.count, 0) -
                   COALESCE(translated.count, 0)
                 )::bigint AS pending_count,
                 (
                   totals.total -
                   COALESCE(source_locales.count, 0)
                 )::bigint AS total_count
          FROM supported
          CROSS JOIN totals
          LEFT JOIN translated_counts translated
            ON translated.base = supported.base
          LEFT JOIN source_locale_counts source_locales
            ON source_locales.base = supported.base
          ORDER BY supported.locale
        SQL

        {
          target_type: "tag",
          locales:
            DB
              .query(sql)
              .map do |row|
                {
                  locale: row.locale,
                  translated_count: row.translated_count,
                  pending_count: row.pending_count,
                  total_count: row.total_count,
                }
              end,
        }
      end

      private

      # all tags that are eligible for translation based on site settings,
      # including those without locale detected yet.
      def self.get
        Tag.all
      end

      def self.calculate_completion_per_locale(locale)
        base_locale = "#{locale.split("_").first}%"
        sql = <<~SQL
          WITH eligible_tags AS (
            #{get.where.not(tags: { locale: nil }).to_sql}
          ),
          total_count AS (
            SELECT COUNT(*) AS count FROM eligible_tags
          ),
          done_count AS (
            SELECT COUNT(DISTINCT t.id)
            FROM eligible_tags t
            LEFT JOIN tag_localizations tl ON t.id = tl.tag_id AND tl.locale LIKE :base_locale
            WHERE t.locale LIKE :base_locale OR tl.tag_id IS NOT NULL
          )
          SELECT d.count AS done, t.count AS total
          FROM total_count t, done_count d
        SQL

        done, total = DB.query_single(sql, base_locale:)
        { done:, total: }
      end
    end
  end
end
