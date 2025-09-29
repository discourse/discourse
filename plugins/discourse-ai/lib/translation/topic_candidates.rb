# frozen_string_literal: true

module DiscourseAi
  module Translation
    class TopicCandidates < BaseCandidates
      private

      # all topics that are eligible for translation based on site settings,
      # including those without locale detected yet.
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

      def self.calculate_completion_per_locale(locale)
        base_locale = "#{locale.split("_").first}%"

        sql = <<~SQL
          WITH eligible_topics AS (
            #{get.where("topics.locale IS NOT NULL").to_sql}
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
