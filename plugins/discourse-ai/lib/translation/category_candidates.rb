# frozen_string_literal: true

module DiscourseAi
  module Translation
    class CategoryCandidates < BaseCandidates
      def self.progress_summary
        supported_locales = SiteSetting.content_localization_supported_locales.split("|")
        eligible_categories_sql = get.select(:id, :locale).to_sql

        sql = <<~SQL
          WITH supported AS MATERIALIZED (
            SELECT COALESCE(
              array_agg(
                DISTINCT split_part(lower(replace(locale, '-', '_')), '_', 1)
              ) FILTER (WHERE locale IS NOT NULL),
              ARRAY[]::text[]
            ) AS bases
            FROM unnest(ARRAY[:supported_locales]::text[]) configured(locale)
          ),
          eligible_categories AS (
            SELECT id,
                   locale,
                   split_part(
                     lower(replace(locale, '-', '_')), '_', 1
                   ) AS source_base
            FROM (#{eligible_categories_sql}) candidates
          ),
          localization_coverage AS (
            SELECT cl.category_id,
                   array_agg(
                     split_part(
                       lower(replace(cl.locale, '-', '_')), '_', 1
                     )
                   ) AS bases
            FROM category_localizations cl
            GROUP BY cl.category_id
          )
          SELECT
            COUNT(*)::bigint AS total_count,
            COUNT(*) FILTER (
              WHERE ec.locale IS NOT NULL
                AND supported.bases <@ (
                  COALESCE(lc.bases, ARRAY[]::text[]) || ec.source_base
                )
            )::bigint AS translated_count,
            COUNT(*) FILTER (
              WHERE ec.locale IS NULL
            )::bigint AS needs_language_detection_count
          FROM eligible_categories ec
          CROSS JOIN supported
          LEFT JOIN localization_coverage lc ON lc.category_id = ec.id
        SQL

        result = DB.query(sql, supported_locales:).first

        {
          target_type: "category",
          total_count: result.total_count,
          translated_count: result.translated_count,
          needs_language_detection_count: result.needs_language_detection_count,
        }
      end

      def self.progress_details
        eligible_categories_sql = get.select("categories.id, categories.locale").to_sql
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
          eligible_categories AS MATERIALIZED (
            SELECT categories.id,
                   categories.locale,
                   split_part(
                     lower(replace(categories.locale, '-', '_')), '_', 1
                   ) AS base
            FROM (#{eligible_categories_sql}) categories
          ),
          totals AS (
            SELECT COUNT(*)::bigint AS total
            FROM eligible_categories
          ),
          source_locale_counts AS (
            SELECT base,
                   COUNT(*)::bigint AS count
            FROM eligible_categories
            WHERE locale IS NOT NULL
            GROUP BY base
          ),
          translated_counts AS (
            SELECT supported.base,
                   COUNT(DISTINCT categories.id)::bigint AS count
            FROM eligible_categories categories
            JOIN category_localizations localization
              ON localization.category_id = categories.id
            JOIN supported
              ON supported.base = split_part(
                lower(replace(localization.locale, '-', '_')), '_', 1
              )
            WHERE categories.locale IS NOT NULL
              AND categories.base <> supported.base
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
                 )::bigint AS eligible_count
          FROM supported
          CROSS JOIN totals
          LEFT JOIN translated_counts translated
            ON translated.base = supported.base
          LEFT JOIN source_locale_counts source_locales
            ON source_locales.base = supported.base
          ORDER BY supported.locale
        SQL

        {
          target_type: "category",
          locales:
            DB
              .query(sql)
              .map do |row|
                {
                  locale: row.locale,
                  translated_count: row.translated_count,
                  pending_count: row.pending_count,
                  eligible_count: row.eligible_count,
                }
              end,
        }
      end

      private

      # all categories that are eligible for translation based on site settings,
      # including those without locale detected yet.
      def self.get
        categories = Category.all
        case SiteSetting.ai_translation_category_scope
        when "public"
          categories.where(read_restricted: false)
        when "include"
          categories.where(id: DiscourseAi::Translation.category_ids_with_subcategories)
        when "include_strict"
          categories.where(id: DiscourseAi::Translation.category_ids)
        when "exclude"
          categories.where.not(id: DiscourseAi::Translation.category_ids_with_subcategories)
        when "exclude_strict"
          categories.where.not(id: DiscourseAi::Translation.category_ids)
        else
          categories
        end
      end

      def self.calculate_completion_per_locale(locale)
        base_locale = "#{locale.split("_").first}%"
        sql = <<~SQL
          WITH eligible_categories AS (
            #{get.where.not(categories: { locale: nil }).to_sql}
          ),
          total_count AS (
            SELECT COUNT(*) AS count FROM eligible_categories
          ),
          done_count AS (
            SELECT COUNT(DISTINCT c.id)
            FROM eligible_categories c
            LEFT JOIN category_localizations cl ON c.id = cl.category_id AND cl.locale LIKE :base_locale
            WHERE c.locale LIKE :base_locale OR cl.category_id IS NOT NULL
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
