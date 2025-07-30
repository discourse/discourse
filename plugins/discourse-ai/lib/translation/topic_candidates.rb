# frozen_string_literal: true

module DiscourseAi
  module Translation
    class TopicCandidates
      # Topics that are eligible for translation based on site settings
      def self.get
        topics =
          Topic
            .where(
              "topics.created_at > ?",
              SiteSetting.ai_translation_backfill_max_age_days.days.ago,
            )
            .where(deleted_at: nil)
            .where("topics.user_id > 0")

        if SiteSetting.ai_translation_backfill_limit_to_public_content
          # exclude all PMs
          # and only include topics from public categories
          topics =
            topics
              .where.not(archetype: Archetype.private_message)
              .where(category_id: Category.where(read_restricted: false).select(:id))
        else
          # all regular topics, and group PMs
          topics =
            topics.where(
              "topics.archetype != ? OR topics.id IN (SELECT topic_id FROM topic_allowed_groups)",
              Archetype.private_message,
            )
        end
      end

      def self.get_completion_per_locale(locale)
        total = get.count
        return 1.0 if total.zero?

        base_locale = "#{locale.split("_").first}%"
        sql = <<~SQL
          WITH eligible_topics AS (
            #{get.to_sql}
          )
          SELECT COUNT(DISTINCT t.id)
          FROM eligible_topics t
          LEFT JOIN topic_localizations tl ON t.id = tl.topic_id AND tl.locale LIKE :base_locale
          WHERE t.locale LIKE :base_locale OR tl.topic_id IS NOT NULL
        SQL

        done = DB.query_single(sql, base_locale:).first.to_i || 0
        done / total.to_f
      end
    end
  end
end
