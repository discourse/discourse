# frozen_string_literal: true

module DiscourseAi
  module Translation
    class TopicCandidates < BaseCandidates
      def self.progress_summary
        supported_locales = SiteSetting.content_localization_supported_locales.split("|")
        eligible_topics_sql = get.select(:id, :locale).to_sql

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
          eligible_topics AS (
            SELECT id,
                   locale,
                   split_part(
                     lower(replace(locale, '-', '_')), '_', 1
                   ) AS source_base
            FROM (#{eligible_topics_sql}) candidates
          ),
          localization_coverage AS (
            SELECT tl.topic_id,
                   array_agg(
                     split_part(
                       lower(replace(tl.locale, '-', '_')), '_', 1
                     )
                   ) AS bases
            FROM topic_localizations tl
            GROUP BY tl.topic_id
          )
          SELECT
            COUNT(*)::bigint AS total_count,
            COUNT(*) FILTER (
              WHERE et.locale IS NOT NULL
                AND supported.bases <@ (
                  COALESCE(lc.bases, ARRAY[]::text[]) || et.source_base
                )
            )::bigint AS translated_count,
            COUNT(*) FILTER (
              WHERE et.locale IS NULL
            )::bigint AS needs_language_detection_count
          FROM eligible_topics et
          CROSS JOIN supported
          LEFT JOIN localization_coverage lc ON lc.topic_id = et.id
        SQL

        result = DB.query(sql, supported_locales:).first

        {
          target_type: "topic",
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
          SELECT et.id AS topic_id, target.target_locale
          FROM (#{base_sql}) et
          JOIN (VALUES #{target_locale_values}) AS target(base_locale, target_locale)
            ON target.base_locale != split_part(et.locale, '_', 1)
          WHERE NOT EXISTS (
            SELECT 1 FROM topic_localizations tl
            WHERE tl.topic_id = et.id
              AND split_part(tl.locale, '_', 1) = target.base_locale
          )
          ORDER BY et.updated_at DESC, target.target_locale
          LIMIT #{limit.to_i}
        SQL

        DB.query(sql).map { |r| [r.topic_id, r.target_locale] }
      end

      private

      # all topics that are eligible for translation based on site settings,
      # including those without locale detected yet.
      def self.get
        topics =
          Topic.where(
            "topics.created_at > ?",
            SiteSetting.ai_translation_backfill_max_age_days.days.ago,
          ).where(deleted_at: nil)

        topics =
          topics.where("topics.user_id > 0") unless SiteSetting.ai_translation_include_bot_content

        pm_scope = SiteSetting.ai_translation_personal_messages
        category_condition, category_params =
          DiscourseAi::Translation.category_scope_condition(category_column: "topics.category_id")

        topics =
          topics.where(
            "topics.archetype = :pm OR (#{category_condition})",
            category_params.merge(pm: Archetype.private_message),
          )

        # PM scope filter
        case pm_scope
        when "group"
          topics =
            topics.where(
              "topics.archetype != :pm OR topics.id IN (SELECT topic_id FROM topic_allowed_groups)",
              pm: Archetype.private_message,
            )
        when "none", nil
          topics = topics.where.not(archetype: Archetype.private_message)
        end

        # Always include banner topics regardless of age or category filters
        banner_topics = Topic.where(archetype: Archetype.banner, deleted_at: nil)
        topics = topics.or(banner_topics)

        topics
      end

      def self.calculate_completion_per_locale(locale)
        base_locale = "#{locale.split("_").first}%"

        sql = <<~SQL
          WITH eligible_topics AS (
            #{get.where.not(topics: { locale: nil }).to_sql}
          ),
          total_count AS (
            SELECT COUNT(*) AS count FROM eligible_topics
          ),
          done_count AS (
            SELECT COUNT(DISTINCT t.id)
            FROM eligible_topics t
            LEFT JOIN topic_localizations tl ON t.id = tl.topic_id AND tl.locale LIKE :base_locale
            WHERE t.locale LIKE :base_locale OR tl.topic_id IS NOT NULL
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
