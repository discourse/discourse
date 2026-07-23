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
