# frozen_string_literal: true

module DiscourseAi
  module Translation
    class PostCandidates
      def self.progress_summary
        supported_locales = SiteSetting.content_localization_supported_locales.split("|")
        eligible_posts_sql = get.select(:id, :locale).to_sql

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
          eligible_posts AS (
            SELECT id,
                   locale,
                   split_part(
                     lower(replace(locale, '-', '_')), '_', 1
                   ) AS source_base
            FROM (#{eligible_posts_sql}) candidates
          ),
          localization_coverage AS (
            SELECT pl.post_id,
                   array_agg(
                     split_part(
                       lower(replace(pl.locale, '-', '_')), '_', 1
                     )
                   ) AS bases
            FROM post_localizations pl
            GROUP BY pl.post_id
          )
          SELECT
            COUNT(*)::bigint AS total_count,
            COUNT(*) FILTER (
              WHERE ep.locale IS NOT NULL
                AND supported.bases <@ (
                  COALESCE(lc.bases, ARRAY[]::text[]) || ep.source_base
                )
            )::bigint AS translated_count,
            COUNT(*) FILTER (
              WHERE ep.locale IS NULL
            )::bigint AS needs_language_detection_count
          FROM eligible_posts ep
          CROSS JOIN supported
          LEFT JOIN localization_coverage lc ON lc.post_id = ep.id
        SQL

        result = DB.query(sql, supported_locales:).first

        {
          target_type: "post",
          total_count: result.total_count,
          translated_count: result.translated_count,
          needs_language_detection_count: result.needs_language_detection_count,
        }
      end

      def self.needs_localization(limit:)
        locales = DiscourseAi::Translation.locales
        return [] if locales.blank?

        locale_map = {}
        locales.each { |l| locale_map[l.split("_").first] ||= l }

        target_locale_values = locale_map.map { |base, full| "('#{base}', '#{full}')" }.join(", ")

        base_sql = get.where.not(locale: nil).to_sql

        sql = <<~SQL
          SELECT ep.id AS post_id, target.target_locale
          FROM (#{base_sql}) ep
          JOIN (VALUES #{target_locale_values}) AS target(base_locale, target_locale)
            ON target.base_locale != split_part(ep.locale, '_', 1)
          WHERE NOT EXISTS (
            SELECT 1 FROM post_localizations pl
            WHERE pl.post_id = ep.id
              AND split_part(pl.locale, '_', 1) = target.base_locale
          )
          ORDER BY ep.updated_at DESC, target.target_locale
          LIMIT #{limit.to_i}
        SQL

        DB.query(sql).map { |r| [r.post_id, r.target_locale] }
      end

      private

      # all posts that are eligible for translation based on site settings,
      # including those without locale detected yet.
      def self.get
        posts =
          Post
            .where(
              "posts.created_at > ?",
              SiteSetting.ai_translation_backfill_max_age_days.days.ago,
            )
            .where(deleted_at: nil)
            .where.not(raw: [nil, ""])
            .where("LENGTH(posts.raw) <= ?", SiteSetting.ai_translation_max_post_length)

        posts =
          posts.where("posts.user_id > 0") unless SiteSetting.ai_translation_include_bot_content

        posts = posts.joins(:topic)

        pm_scope = SiteSetting.ai_translation_personal_messages
        category_condition, category_params =
          DiscourseAi::Translation.category_scope_condition(category_column: "topics.category_id")

        posts =
          posts.where(
            "topics.archetype = :pm OR (#{category_condition})",
            category_params.merge(pm: Archetype.private_message),
          )

        # PM scope filter
        case pm_scope
        when "group"
          posts =
            posts.where(
              "topics.archetype != :pm OR topics.id IN (SELECT topic_id FROM topic_allowed_groups)",
              pm: Archetype.private_message,
            )
        when "none", nil
          posts = posts.where.not(topics: { archetype: Archetype.private_message })
        end

        # Always include posts from banner topics regardless of age or category filters
        banner_posts =
          Post
            .where(deleted_at: nil)
            .where.not(raw: [nil, ""])
            .where("LENGTH(posts.raw) <= ?", SiteSetting.ai_translation_max_post_length)
            .joins(:topic)
            .where(topics: { archetype: Archetype.banner, deleted_at: nil })
        banner_posts =
          banner_posts.where(
            "posts.user_id > 0",
          ) unless SiteSetting.ai_translation_include_bot_content
        posts = posts.or(banner_posts)

        posts
      end
    end
  end
end
