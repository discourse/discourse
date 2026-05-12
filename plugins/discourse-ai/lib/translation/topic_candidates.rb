# frozen_string_literal: true

module DiscourseAi
  module Translation
    class TopicCandidates < BaseCandidates
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

        target_category_ids = SiteSetting.ai_translation_target_categories
        pm_scope = SiteSetting.ai_translation_personal_messages

        # Category filter: include target categories + PMs (PMs filtered in next step)
        if target_category_ids.present?
          category_ids = target_category_ids.split("|").map(&:to_i)
          topics =
            topics.where(
              "topics.category_id IN (:cats) OR topics.archetype = :pm",
              cats: category_ids,
              pm: Archetype.private_message,
            )
        else
          topics = topics.where(archetype: Archetype.private_message)
        end

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
