# frozen_string_literal: true

module DiscourseAi
  module Translation
    class PostCandidates < BaseCandidates
      # Posts that are eligible for translation based on site settings
      def self.get
        posts =
          Post
            .where(
              "posts.created_at > ?",
              SiteSetting.ai_translation_backfill_max_age_days.days.ago,
            )
            .where(deleted_at: nil)
            .where("posts.user_id > 0")
            .where.not(raw: [nil, ""])

        posts = posts.joins(:topic)
        if SiteSetting.ai_translation_backfill_limit_to_public_content
          # exclude all PMs
          # and only include posts from public categories
          posts =
            posts
              .where.not(topics: { archetype: Archetype.private_message })
              .where(topics: { category_id: Category.where(read_restricted: false).select(:id) })
        else
          # all regular topics, and group PMs
          posts =
            posts.where(
              "topics.archetype != ? OR topics.id IN (SELECT topic_id FROM topic_allowed_groups)",
              Archetype.private_message,
            )
        end
      end

      private

      def self.calculate_completion_per_locale(locale)
        base_locale = "#{locale.split("_").first}%"

        sql = <<~SQL
          WITH eligible_posts AS (
            #{get.to_sql}
          ),
          total_count AS (
            SELECT COUNT(*) AS count FROM eligible_posts
          ),
          done_count AS (
            SELECT COUNT(DISTINCT p.id)
            FROM eligible_posts p
            LEFT JOIN post_localizations pl ON p.id = pl.post_id AND pl.locale LIKE :base_locale
            WHERE p.locale LIKE :base_locale OR pl.post_id IS NOT NULL
          )
          SELECT d.count AS done, t.count AS total
          FROM total_count t, done_count d
        SQL

        DB.query_single(sql, base_locale: "#{base_locale}%")
      end

      def self.completion_cache_key_for_type
        "discourse_ai::translation::post_candidates"
      end
    end
  end
end
