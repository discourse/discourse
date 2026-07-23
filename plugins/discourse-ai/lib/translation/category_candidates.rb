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
